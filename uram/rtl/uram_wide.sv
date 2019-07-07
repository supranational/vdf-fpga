/*
  Copyright 2019 Supranational LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

// This module implements an arbitrary width URAM.
// Data is written in slowly (default 8 bits at a time) and read
// at full bandwidth.

module uram_wide
  #(
    parameter ADDR_LEN = 9,
    parameter DATA_LEN = 128,
    parameter DIN_LEN  = 8
    ) 
   ( 
     input                     clk,
     input                     we,
     input [DIN_LEN-1:0]       din,
     input                     din_valid,
     input [ADDR_LEN-1:0]      addr,
     output reg [DATA_LEN-1:0] dout
     );
   
   localparam int  URAM_WIDTH     = 72;
   // Round up
   localparam int  NUM_URAMS      = (DATA_LEN + URAM_WIDTH - 1) / URAM_WIDTH;
   localparam int  XFERS_PER_ROW  = DATA_LEN/DIN_LEN;
   localparam int  TOT_URAM_WIDTH = NUM_URAMS*URAM_WIDTH;

   localparam int  INPUT_STAGES   = 1;

   logic [DIN_LEN-1:0]                din_stage[INPUT_STAGES];
   logic                              din_valid_stage[INPUT_STAGES];
   logic                              we_stage[INPUT_STAGES];
   
   logic                              we_uram;
   logic [TOT_URAM_WIDTH-1:0]         din_uram;
   /* verilator lint_off UNUSED */
   logic [TOT_URAM_WIDTH-1:0]         dout_uram;
   /* verilator lint_on UNUSED */
   logic [DATA_LEN-1:0]               din_buffer;
   logic [ADDR_LEN-1:0]               write_uram_addr;
   logic [$clog2(XFERS_PER_ROW)-1:0]  xfer_count;

   genvar          i;

   // Stage the inputs to relieve timing constraints
   always_ff @(posedge clk) begin
      we_stage[0]           <= we;
      for(int j = 1; j < INPUT_STAGES; j++) begin
         we_stage[j]        <= we_stage[j-1];
      end
   end
   always_ff @(posedge clk) begin
      if(!we_stage[INPUT_STAGES-1]) begin
         for(int j = 0; j < INPUT_STAGES; j++) begin
            din_valid_stage[j] <= 0;
         end
      end else begin
         din_stage[0]          <= din;
         din_valid_stage[0]    <= din_valid;
         for(int j = 1; j < INPUT_STAGES; j++) begin
            din_stage[j]       <= din_stage[j-1];
            din_valid_stage[j] <= din_valid_stage[j-1];
         end
      end
   end

   generate
      for(i = 0; i < NUM_URAMS; i++) begin : uram_cells
         uram #(.DATA_LEN(URAM_WIDTH),
                .ADDR_LEN(ADDR_LEN)
                )
         uram_cell 
              (
               .clk (clk),
               .we  (we_uram),
               .din (din_uram[i*URAM_WIDTH +: URAM_WIDTH]),
               .addr(we_uram ? write_uram_addr : addr),
               .dout(dout_uram[i*URAM_WIDTH +: URAM_WIDTH])
               );
      end
   endgenerate

   assign dout     = dout_uram[DATA_LEN-1:0];
   assign din_uram = {{(TOT_URAM_WIDTH-DATA_LEN){1'b0}}, din_buffer};

   // Enable writing data into the URAMs
   // Accumulate and write a row's worth of data at a time.
   always_ff @(posedge clk) begin
      if(!we_stage[INPUT_STAGES-1]) begin
         write_uram_addr    <= 0;
         xfer_count         <= XFERS_PER_ROW[$clog2(XFERS_PER_ROW)-1:0];
         din_buffer         <= 0;
         we_uram            <= 0;
      end else if(we_stage[INPUT_STAGES-1] && 
                  din_valid_stage[INPUT_STAGES-1]) begin
         // Buffer the incoming data
         din_buffer         <= {din_stage[INPUT_STAGES-1], 
                                din_buffer[DATA_LEN-1:DIN_LEN]};
         xfer_count         <= xfer_count - 1;

         if(xfer_count == 1) begin
            // Write the row next cycle
            we_uram         <= 1;
            xfer_count      <= XFERS_PER_ROW[$clog2(XFERS_PER_ROW)-1:0];;
         end else begin
            we_uram         <= 0;
         end
         if(we_uram) begin
            // Just wrote a row, advance the address
            write_uram_addr <= write_uram_addr + 1;
         end
      end
   end
endmodule
