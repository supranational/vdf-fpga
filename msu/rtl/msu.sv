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

`include "msuconfig.vh"

// MSU configuration
`ifndef SQ_IN_BITS_DEF
 `define SQ_IN_BITS_DEF  1024
`endif
`ifndef SQ_OUT_BITS_DEF
 `define SQ_OUT_BITS_DEF 1024
`endif


module msu
  #(
    // Data width of both input and output data on AXI bus.
    parameter int AXI_LEN               = 32,
    parameter int C_XFER_SIZE_WIDTH     = 32,

    parameter int SQ_IN_BITS            = `SQ_IN_BITS_DEF,
    parameter int SQ_OUT_BITS           = `SQ_OUT_BITS_DEF,
    parameter int T_LEN                 = 64
    )
   (
    input wire                          clk,
    input wire                          reset,

    // Incoming AXI interface.
    input wire                          s_axis_tvalid,
    output wire                         s_axis_tready,
    input wire [AXI_LEN-1:0]            s_axis_tdata,
    /* verilator lint_off UNUSED */
    input wire [AXI_LEN/8-1:0]          s_axis_tkeep,
    /* verilator lint_on UNUSED */
    input wire                          s_axis_tlast,
    output wire [C_XFER_SIZE_WIDTH-1:0] s_axis_xfer_size_in_bytes,
    
    // Outgoing AXI interface.
    output wire                         m_axis_tvalid,
    input wire                          m_axis_tready,
    output wire [AXI_LEN-1:0]           m_axis_tdata,
    output wire [AXI_LEN/8-1:0]         m_axis_tkeep,
    output wire                         m_axis_tlast,
    output wire [C_XFER_SIZE_WIDTH-1:0] m_axis_xfer_size_in_bytes,
    /* verilator lint_off UNUSED */
    input wire                          ap_start,
    /* verilator lint_on UNUSED */
    output wire                         ap_done,
    output wire                         start_xfer
    );

   // Incoming txn count: t_start, t_final, sq_in
   localparam int AXI_IN_COUNT      = (T_LEN/AXI_LEN*2 + 
                                       SQ_IN_BITS / AXI_LEN);
   // Outgoing txn count: t_current, sq_out
   localparam int AXI_OUT_COUNT     = (T_LEN/AXI_LEN + 
                                       SQ_OUT_BITS / AXI_LEN);
   localparam int AXI_BYTES_PER_TXN = AXI_LEN/8;
   localparam int AXI_IN_BITS       = AXI_IN_COUNT * AXI_LEN;
   localparam int AXI_OUT_BITS      = AXI_OUT_COUNT * AXI_LEN;
   

   // State machine states.
   typedef enum {
         STATE_INIT,
         STATE_RECV,
         STATE_SQIN,
         STATE_START,
         STATE_COMPUTE,
         STATE_PREPARE_SEND,
         STATE_SEND,
         STATE_IDLE
   } State;
   State state;
   State next_state;

   // Squaring parameters
   logic [T_LEN-1:0]             t_current;
   logic [T_LEN-1:0]             t_final;
   logic [SQ_IN_BITS-1:0]        sq_in;
   logic [SQ_OUT_BITS-1:0]       sq_out;

   logic                         sq_start;
   logic                         sq_finished;

   logic                         final_iteration;
   
   // AXI data storage
   logic [AXI_IN_BITS-1:0]       axi_in;
   logic [AXI_OUT_BITS-1:0]      axi_out;
   logic [C_XFER_SIZE_WIDTH-1:0] axi_out_count;
   logic                         axi_in_shift;


   genvar                        gi;
   
   // Xilinx recommends clocking reset. 
   logic        reset_1d;
   always @(posedge clk) begin
      reset_1d <= reset;
   end


   //////////////////////////////////////////////////////////////////////
   // State machine
   //////////////////////////////////////////////////////////////////////

   always @(posedge clk) begin
      state <= next_state;
   end

   always_comb begin
      if(reset_1d) begin
         next_state           = STATE_INIT;
      end else begin
         case(state)
           STATE_INIT:
             if(ap_start) begin
                next_state    = STATE_RECV;
             end else begin
                next_state    = STATE_INIT;
             end

           STATE_RECV:
             if(s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
                next_state    = STATE_SQIN;
             end else begin
                next_state    = STATE_RECV;
             end

           STATE_SQIN:
             next_state       = STATE_START;

           STATE_START:
             next_state       = STATE_COMPUTE;

           STATE_COMPUTE:
             if(t_current == t_final) begin
                next_state    = STATE_PREPARE_SEND;
             end else begin
                next_state    = STATE_COMPUTE;
             end

           STATE_PREPARE_SEND:
             next_state       = STATE_SEND;

           STATE_SEND:
             if(axi_out_count == AXI_OUT_COUNT-1 && m_axis_tready) begin
                next_state    = STATE_IDLE;
             end else begin
                next_state    = STATE_SEND;
             end
           
           STATE_IDLE:
             next_state       = STATE_INIT;

           default:
             next_state       = STATE_INIT;
         endcase
      end
   end

   //////////////////////////////////////////////////////////////////////
   // Receive AXI data
   //////////////////////////////////////////////////////////////////////
   assign axi_in_shift = state == STATE_RECV && s_axis_tvalid;

   always @(posedge clk) begin
      if(axi_in_shift) begin
         axi_in <= { s_axis_tdata, axi_in[AXI_IN_BITS-1:AXI_LEN] };
      end
   end

   always @(posedge clk) begin
      if(state == STATE_SQIN) begin
         t_current            <= axi_in[T_LEN-1:0];
         t_final              <= axi_in[2*T_LEN-1:T_LEN];
         sq_in                <= axi_in[AXI_IN_BITS-1:2*T_LEN];
      end else if(state == STATE_COMPUTE && sq_finished) begin
         t_current            <= t_current + 1;
      end
   end
   assign final_iteration = sq_finished && (t_current == t_final-1);

   assign sq_start                  = state == STATE_START;
   assign s_axis_xfer_size_in_bytes = (AXI_IN_COUNT*AXI_BYTES_PER_TXN);
   assign s_axis_tready             = (state == STATE_RECV);
   
   //////////////////////////////////////////////////////////////////////
   // Modsqr function
   //////////////////////////////////////////////////////////////////////

`ifdef SIMPLE_SQ
   modular_square_simple
`else
   modular_square_wrapper
`endif
     #(
       .MOD_LEN(SQ_IN_BITS)
       )
   modsqr
     (
      .clk                (clk),
      .reset              (reset || reset_1d || state == STATE_RECV),
      .start              (sq_start),
      .sq_in              (sq_in),
      .sq_out             (sq_out),
      .valid              (sq_finished)
      );

   //////////////////////////////////////////////////////////////////////
   // Send AXI data
   //////////////////////////////////////////////////////////////////////
   localparam int SQ_OUT_OFFSET = 2;
   always @(posedge clk) begin
      if(final_iteration) begin
         axi_out_count                 <= 0;
         axi_out[T_LEN-1:0]            <= t_current;
         axi_out[AXI_OUT_BITS-1:T_LEN] <= sq_out;
      end else if(state == STATE_SEND && m_axis_tready) begin
         axi_out                       <= { {AXI_LEN{1'b0}},
                                            axi_out[AXI_OUT_BITS-1:AXI_LEN] };

         axi_out_count               <= axi_out_count + 1;
      end
   end

   assign m_axis_xfer_size_in_bytes = AXI_OUT_COUNT*AXI_BYTES_PER_TXN;
   assign m_axis_tvalid             = (state == STATE_SEND && 
                                       axi_out_count < AXI_OUT_COUNT);
   assign m_axis_tdata              = axi_out[AXI_LEN-1:0];
   assign m_axis_tlast              = 0;
   assign m_axis_tkeep              = {(AXI_LEN/8){1'b1}};
   assign start_xfer                = state == STATE_PREPARE_SEND;
   assign ap_done                   = state == STATE_IDLE;
endmodule

// Local Variables:
// verilog-library-directories:("." "../hw" "../../squarer_6_13/rtl/")
// End:
