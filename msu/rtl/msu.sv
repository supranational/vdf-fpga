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

module msu
  #(
    // Data width of both input and output data on AXI bus.
    parameter int AXI_LEN               = 32,
    parameter int C_XFER_SIZE_WIDTH     = 32,

    parameter int REDUNDANT_ELEMENTS    = 2,
    parameter int NONREDUNDANT_ELEMENTS = 64,
    parameter int NUM_ELEMENTS          = (NONREDUNDANT_ELEMENTS+
                                           REDUNDANT_ELEMENTS),
    parameter int BIT_LEN               = 17,
    parameter int WORD_LEN              = 16,
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
    output wire                         start_xfer,
    input                               reduction_we
    );

   // Incoming txn count: t_start, t_final, sq_in (reduced form, two per txn)
   localparam int AXI_IN_COUNT      = (T_LEN/AXI_LEN*2 + 
                                       (NONREDUNDANT_ELEMENTS+1)/2);
   // Outgoing txn count: t_current, sq_out (reduntant form, one per txn )
   localparam int AXI_OUT_COUNT     = (T_LEN/AXI_LEN + NUM_ELEMENTS);
   localparam int AXI_BYTES_PER_TXN = AXI_LEN/8;
   

   // State machine states.
   typedef enum {
         STATE_INIT,
         STATE_RECV,
         STATE_REDTX,
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
   logic [BIT_LEN-1:0]           sq_in[NUM_ELEMENTS];
   logic [BIT_LEN-1:0]           sq_out[NUM_ELEMENTS];

   logic sq_start;
   logic sq_finished;
   
   // AXI data storage
   logic [AXI_LEN-1:0]           axi_in[AXI_IN_COUNT];
   logic [AXI_LEN-1:0]           axi_out[AXI_OUT_COUNT];
   logic [C_XFER_SIZE_WIDTH-1:0] axi_out_count;
   logic                         axi_in_shift;

   // Reduction table write support
   typedef enum {
       RSTATE_INIT,
       RSTATE_TX
   } RState;
   RState rstate;

   localparam int                    REDUCTION_DIN_LEN = 8;
   localparam int                    REDUCTION_WRITE_XFERS = 
                                         (NONREDUNDANT_ELEMENTS*WORD_LEN / 
                                          REDUCTION_DIN_LEN);
   localparam int                    REDUCTION_XFERS_PER_AXI =
                                         (AXI_LEN/REDUCTION_DIN_LEN);
   logic [C_XFER_SIZE_WIDTH-1:0]     reduction_txns_remaining;

   logic [AXI_LEN-1:0]               reduction_din;
   logic [REDUCTION_XFERS_PER_AXI-1:0] reduction_din_valid;
   logic                             reduction_done;
   logic                             reduction_in_shift;



   int                           i;
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
                next_state       = STATE_RECV;
             end else begin
                next_state       = STATE_INIT;
             end

           STATE_RECV:
             if(s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
                if(reduction_we) begin
                   next_state    = STATE_REDTX;
                end else begin
                   next_state    = STATE_SQIN;
                end   
             end else begin
                next_state    = STATE_RECV;
             end

           STATE_REDTX:
             if(reduction_done) begin
                next_state    = STATE_INIT;
             end else begin
                next_state    = STATE_REDTX;
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
   localparam int SQ_IN_OFFSET = 4;
   always @(posedge clk) begin
      if(state == STATE_START) begin
         t_current            <= {axi_in[1], axi_in[0]};
         t_final              <= {axi_in[3], axi_in[2]};
      end else if(state == STATE_COMPUTE && sq_finished) begin
         t_current            <= t_current + 1;
      end
   end

   assign axi_in_shift = ((state == STATE_REDTX && reduction_we) ?
                          reduction_in_shift :
                          state == STATE_RECV && s_axis_tvalid);

   always @(posedge clk) begin
      if(axi_in_shift) begin
         // This should synthesize into a shift register
         for(i = 0; i < AXI_IN_COUNT-1; i++) begin
            axi_in[i]         <= axi_in[i+1];
         end
         axi_in[AXI_IN_COUNT-1] <= s_axis_tdata;
      end
   end

   assign sq_start                  = state == STATE_START;
   assign s_axis_xfer_size_in_bytes = (AXI_IN_COUNT*AXI_BYTES_PER_TXN);
   assign s_axis_tready             = (state == STATE_RECV);
   
   generate
      for(gi = 0; gi < NONREDUNDANT_ELEMENTS; gi++) begin
         // Extract appropriate AXI txn, then select upper or lower half of
         // the AXI transaction based on odd or even since there are two
         // elements per transaction.
         always @(posedge clk) begin
            if(state == STATE_SQIN) begin
               sq_in[gi]      <= {{(BIT_LEN-WORD_LEN){1'b0}},
                                  axi_in[gi/2+SQ_IN_OFFSET]
                                  [AXI_LEN/2*(gi%2) +: WORD_LEN]};
            end
         end
      end
      for(gi = NONREDUNDANT_ELEMENTS; gi < NUM_ELEMENTS; gi++) begin
         always @(posedge clk) begin
            if(state == STATE_SQIN) begin
               sq_in[gi]      <= 0;
            end
         end
      end
   endgenerate

   //////////////////////////////////////////////////////////////////////
   // Reduction table writing
   //////////////////////////////////////////////////////////////////////

   always_ff @(posedge clk) begin
      if(reset || !reduction_we) begin
         rstate                       <= RSTATE_INIT;
         reduction_din_valid          <= 0;
      end else begin
         case(rstate)
           RSTATE_INIT: begin
              if(state == STATE_REDTX) begin
                 reduction_txns_remaining <= REDUCTION_WRITE_XFERS;
                 rstate               <= RSTATE_TX;
                 reduction_din        <= axi_in[0];
                 reduction_din_valid  <= 2**REDUCTION_XFERS_PER_AXI-1;
              end else begin
                 rstate               <= RSTATE_INIT;
              end
           end

           RSTATE_TX: begin
              if(reduction_txns_remaining == 1) begin
                 rstate               <= RSTATE_INIT;
                 reduction_din_valid          <= 0;
              end else begin
                 rstate               <= RSTATE_TX;
                 reduction_txns_remaining <= reduction_txns_remaining-1;
                 if(reduction_din_valid[1] == 0) begin
                    reduction_din_valid  <= 2**REDUCTION_XFERS_PER_AXI-1;
                    reduction_din        <= axi_in[1];
                 end else begin
                    reduction_din_valid  <= reduction_din_valid >> 1;
                    reduction_din        <= reduction_din >> REDUCTION_DIN_LEN;
                 end
              end
           end
         endcase
      end
   end
   assign reduction_done      = (rstate == RSTATE_TX &&
                                 reduction_txns_remaining == 1);
   assign reduction_in_shift  = (rstate == RSTATE_TX &&
                                 reduction_din_valid[1] == 0);

   //////////////////////////////////////////////////////////////////////
   // Modsqr function
   //////////////////////////////////////////////////////////////////////

   modular_square_wrapper
     #(
       .REDUNDANT_ELEMENTS(REDUNDANT_ELEMENTS),
       .NONREDUNDANT_ELEMENTS(NONREDUNDANT_ELEMENTS),
       .BIT_LEN(BIT_LEN),
       .WORD_LEN(WORD_LEN),
       .REDUCTION_DIN_LEN(REDUCTION_DIN_LEN)
       )
   modsqr
     (
      .clk                (clk),
      .rst                (reset || reset_1d || state == STATE_RECV),
      .start              (sq_start),
      .sq_in              (sq_in),
      .sq_out             (sq_out),
      .valid              (sq_finished),
      .reduction_we       (reduction_we),
      .reduction_din      (reduction_din[REDUCTION_DIN_LEN-1:0]),
      .reduction_din_valid(reduction_din_valid[0])
      );

   //////////////////////////////////////////////////////////////////////
   // Send AXI data
   //////////////////////////////////////////////////////////////////////
   localparam int SQ_OUT_OFFSET = 2;
   always @(posedge clk) begin
      if(state == STATE_PREPARE_SEND) begin
         axi_out_count               <= 0;
         {axi_out[1], axi_out[0]}    <= t_current;
         for(i = 0; i < AXI_OUT_COUNT-2; i++) begin
            axi_out[i+SQ_OUT_OFFSET] <= {{(AXI_LEN-BIT_LEN){1'b0}},
                                         sq_out[i]};
         end
      end else if(state == STATE_SEND && m_axis_tready) begin
         // This should synthesize into a shift register
         axi_out[AXI_OUT_COUNT-1]    <= 0;
         for(i = 0; i < AXI_OUT_COUNT-1; i++) begin
            axi_out[i]               <= axi_out[i+1];
         end

         axi_out_count               <= axi_out_count + 1;
      end
   end

   assign m_axis_xfer_size_in_bytes = (reduction_we ? 0 :
                                       AXI_OUT_COUNT*AXI_BYTES_PER_TXN);
   assign m_axis_tvalid             = (state == STATE_SEND && 
                                       axi_out_count < AXI_OUT_COUNT);
   assign m_axis_tdata              = axi_out[0];
   assign m_axis_tlast              = 0;
   assign m_axis_tkeep              = {(AXI_LEN/8){1'b1}};
   assign start_xfer                = state == STATE_PREPARE_SEND;
   assign ap_done                   = (reduction_we ? reduction_done :
                                       state == STATE_IDLE);
endmodule

// Local Variables:
// verilog-library-directories:("." "../hw" "../../squarer_6_13/rtl/")
// End:
