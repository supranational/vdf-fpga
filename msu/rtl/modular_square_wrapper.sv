/*******************************************************************************
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
*******************************************************************************/

// Pipe the modular squaring circuit IOs to relieve timing pressure. 
`ifndef MOD_LEN_DEF
`define MOD_LEN_DEF 1024
`endif

module modular_square_wrapper
   #(
     parameter int MOD_LEN               = `MOD_LEN_DEF,

     parameter int WORD_LEN              = 16,
     parameter int REDUNDANT_ELEMENTS    = 2,
     parameter int NONREDUNDANT_ELEMENTS = MOD_LEN / WORD_LEN,
     parameter int NUM_ELEMENTS          = REDUNDANT_ELEMENTS +
                                           NONREDUNDANT_ELEMENTS,
     // Send the coefficients out in 32 bits - somewhat inefficient use
     // of space but not timing critical and easier to read/debug
     parameter int SQ_OUT_BITS           = NUM_ELEMENTS * WORD_LEN*2
    )
   (
    input logic                    clk,
    input logic                    reset,
    input logic                    start,
    input logic [MOD_LEN-1:0]      sq_in,
    output logic [SQ_OUT_BITS-1:0] sq_out,
    output logic                   valid
   );

   localparam int BIT_LEN               = 17;
   localparam int IO_STAGES             = 3;

   logic               start_stages[IO_STAGES];
   logic [BIT_LEN-1:0] sq_in_stages[IO_STAGES][NUM_ELEMENTS];
   logic [BIT_LEN-1:0] sq_out_stages[IO_STAGES][NUM_ELEMENTS];
   logic               valid_stages[IO_STAGES];

   genvar              j;

   always_ff @(posedge clk) begin
      start_stages[0]     <= start;
   end

   // Split sq_in into polynomial coefficients
   generate
      for(j = 0; j < NONREDUNDANT_ELEMENTS; j++) begin
         always @(posedge clk) begin
            sq_in_stages[0][j] <= {{(BIT_LEN-WORD_LEN){1'b0}},
                                   sq_in[j*WORD_LEN +: WORD_LEN]};
         end
      end
      // Clear the redundant coefficients
      for(j = NONREDUNDANT_ELEMENTS; j < NUM_ELEMENTS; j++) begin
         always @(posedge clk) begin
            sq_in_stages[0][j] <= 0;
         end
      end
   endgenerate

   // Gather the output coefficients into sq_out
   generate
      for(j = 0; j < NUM_ELEMENTS; j++) begin
         always_comb begin
            sq_out[j*WORD_LEN*2 +: 2*WORD_LEN] = {{(2*WORD_LEN-BIT_LEN){1'b0}},
                                                 sq_out_stages[IO_STAGES-1][j]};
         end
      end
   endgenerate

   assign valid  = valid_stages[IO_STAGES-1];

   // Create the pipeline
   generate
      for(j = 1; j < IO_STAGES; j++) begin
         always_ff @(posedge clk) begin
            start_stages[j]  <= start_stages[j-1];
            sq_in_stages[j]  <= sq_in_stages[j-1];
            sq_out_stages[j] <= sq_out_stages[j-1];
            valid_stages[j]  <= valid_stages[j-1];
         end
      end
   endgenerate

   modular_square_8_cycles 
     #(
       .NONREDUNDANT_ELEMENTS(NONREDUNDANT_ELEMENTS)
       )
   modsqr(
          .clk                (clk),
          .reset              (reset),
          .start              (start_stages[IO_STAGES-1]),
          .sq_in              (sq_in_stages[IO_STAGES-1]),
          .sq_out             (sq_out_stages[0]),
          .valid              (valid_stages[0])
          );

endmodule
