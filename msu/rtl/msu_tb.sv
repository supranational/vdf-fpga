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

`ifndef NONREDUNDANT_ELEMENTS_DEF
 `define NONREDUNDANT_ELEMENTS_DEF 8
`endif
`ifndef REDUNDANT_ELEMENTS_DEF
 `define REDUNDANT_ELEMENTS_DEF 2
`endif
`ifndef WORD_LEN_DEF
 `define WORD_LEN_DEF 16
`endif

module msu_tb
  #(
    parameter int REDUNDANT_ELEMENTS    = `REDUNDANT_ELEMENTS_DEF,
    parameter int NONREDUNDANT_ELEMENTS = `NONREDUNDANT_ELEMENTS_DEF,
    parameter int NUM_ELEMENTS          = (NONREDUNDANT_ELEMENTS+
                                           REDUNDANT_ELEMENTS),
    parameter int BIT_LEN               = `WORD_LEN_DEF+1,
    parameter int WORD_LEN              = `WORD_LEN_DEF,
    parameter int T_LEN                 = 64
    )
   (
    input logic                clk,
    input logic                reset,
    input logic                start,
    input logic [AXI_LEN-1:0]  msu_in[MSU_IN_XFERS],
    output logic [AXI_LEN-1:0] msu_out[MSU_OUT_XFERS],
    output logic               valid
    );

   localparam int              C_XFER_SIZE_WIDTH  = 32;
   localparam int              AXI_LEN            = 32;
   localparam int              AXI_BYTES_PER_XFER = AXI_LEN/8;
   localparam int              MSU_IN_XFERS       = 
                                  (T_LEN/AXI_LEN +     // t_start
                                   T_LEN/AXI_LEN +     // t_final
                                   // y - +1 to round up
                                   (NONREDUNDANT_ELEMENTS+1)/2);
   localparam int              MSU_OUT_XFERS      = 
                                  (T_LEN/AXI_LEN +     // t_intermediate
                                   NUM_ELEMENTS);      // y

   // TB->MSU AXI interface.
   logic                         s_axis_tvalid;
   logic                         s_axis_tready;
   logic [AXI_LEN-1:0]           s_axis_tdata;
   logic [C_XFER_SIZE_WIDTH-1:0] s_axis_xfer_size_in_bytes;
    
   // MSU->TB AXI interface.
   logic                         m_axis_tvalid;
   logic                         m_axis_tready;
   logic [AXI_LEN-1:0]           m_axis_tdata;
   logic [C_XFER_SIZE_WIDTH-1:0] m_axis_xfer_size_in_bytes;
   logic                         start_xfer;                         
   logic                         ap_start;


   typedef enum {
      INIT_S,             // 0
      AWAIT_TB_S,         // 1
      RECV_FROM_TB_S,     // 2
      SEND_TO_MSU_S,      // 3
      AWAIT_MSU_S,        // 4
      RECV_FROM_MSU_S,    // 5
      SEND_TO_TB_S        // 6
   } state_t;
   state_t state;
   state_t next_state;

   logic [C_XFER_SIZE_WIDTH-1:0] remaining_bytes_to_msu;
   logic [C_XFER_SIZE_WIDTH-1:0] index_to_msu;
   logic [C_XFER_SIZE_WIDTH-1:0] remaining_bytes_from_msu;
   logic [C_XFER_SIZE_WIDTH-1:0] index_from_msu;

   //////////////////////////////////////////////////////////////////////
   // State machine
   //////////////////////////////////////////////////////////////////////

   always @(posedge clk) begin
      state <= next_state;
   end

   always_comb begin
      if(reset) begin
         next_state          = INIT_S;
      end else begin
         case(state)
           INIT_S:
             next_state      = AWAIT_TB_S;

           AWAIT_TB_S:
             if(start) begin
                next_state   = RECV_FROM_TB_S;
             end else begin
                next_state   = AWAIT_TB_S;
             end

           RECV_FROM_TB_S:
             next_state      = SEND_TO_MSU_S;

           SEND_TO_MSU_S:
             if(remaining_bytes_to_msu > 0) begin
                next_state   = SEND_TO_MSU_S;
             end else begin
                next_state   = AWAIT_MSU_S;
             end

           AWAIT_MSU_S:
             if(start_xfer) begin
                next_state   = RECV_FROM_MSU_S;
             end else begin
                next_state   = AWAIT_MSU_S;
             end

           RECV_FROM_MSU_S:
             if(remaining_bytes_from_msu > 0) begin
                next_state   = RECV_FROM_MSU_S;
             end else begin
                next_state   = SEND_TO_TB_S;
             end

           SEND_TO_TB_S:
                next_state   = INIT_S;

           default:
             next_state      = INIT_S;

           endcase           
      end
   end

   //////////////////////////////////////////////////////////////////////
   // Transfer data to the MSU
   //////////////////////////////////////////////////////////////////////
   always @(posedge clk) begin
      s_axis_tvalid         <= 0;
      s_axis_tdata          <= 0;
      case(state)
        AWAIT_TB_S: begin
           index_to_msu     <= 0;
           if(s_axis_xfer_size_in_bytes != MSU_IN_XFERS*AXI_BYTES_PER_XFER)
             $display("WARNING: inconsistent MSU data in xfer sizes");
        end
        SEND_TO_MSU_S:
          if(remaining_bytes_to_msu > 0 && s_axis_tready) begin
             index_to_msu   <= index_to_msu + 1;
             s_axis_tvalid  <= 1;
             s_axis_tdata   <= msu_in[index_to_msu];
          end
      endcase
   end
   assign ap_start               = state == AWAIT_TB_S;
   assign remaining_bytes_to_msu = (s_axis_xfer_size_in_bytes - 
                                    index_to_msu * AXI_BYTES_PER_XFER);

   //////////////////////////////////////////////////////////////////////
   // Receive data from the MSU
   //////////////////////////////////////////////////////////////////////
   always @(posedge clk) begin
      m_axis_tready                   <= 0;
      case(state)
        AWAIT_MSU_S: begin
           if(m_axis_xfer_size_in_bytes != MSU_OUT_XFERS*AXI_BYTES_PER_XFER)
             $display("WARNING: inconsistent MSU data out xfer sizes");
           index_from_msu             <= 0;
           m_axis_tready              <= 1;
        end
        RECV_FROM_MSU_S: begin
           m_axis_tready              <= 1;
           if(remaining_bytes_from_msu > 0 && m_axis_tvalid) begin
              msu_out[index_from_msu] <= m_axis_tdata;
              index_from_msu          <= index_from_msu + 1;
           end
        end
      endcase
   end
   assign valid                    = state == SEND_TO_TB_S;
   assign remaining_bytes_from_msu = (m_axis_xfer_size_in_bytes - 
                                      index_from_msu * AXI_BYTES_PER_XFER);

   //////////////////////////////////////////////////////////////////////
   // MSU
   //////////////////////////////////////////////////////////////////////

   /* verilator lint_off PINCONNECTEMPTY */
   msu #(
         .REDUNDANT_ELEMENTS(REDUNDANT_ELEMENTS),
         .NONREDUNDANT_ELEMENTS(NONREDUNDANT_ELEMENTS),
         .BIT_LEN(BIT_LEN),
         .WORD_LEN(WORD_LEN)
         )
     msu(
         .clk                         (clk),
         .reset                       (reset),
         .ap_start                    (ap_start),
         .ap_done                     (),
         // MSU->TB
         .m_axis_tready               (m_axis_tready),
         .m_axis_tvalid               (m_axis_tvalid),
         .m_axis_tdata                (m_axis_tdata[AXI_LEN-1:0]),
         .m_axis_tkeep                (),
         .m_axis_tlast                (),
         .m_axis_xfer_size_in_bytes   (m_axis_xfer_size_in_bytes),
         .start_xfer                  (start_xfer),
         // TB->MSUg
         .s_axis_tready               (s_axis_tready),
         .s_axis_tvalid               (s_axis_tvalid),
         .s_axis_xfer_size_in_bytes   (s_axis_xfer_size_in_bytes),
         .s_axis_tdata                (s_axis_tdata[AXI_LEN-1:0]),
         .s_axis_tkeep                (),
         .s_axis_tlast                ()
         );
   /* verilator lint_on PINCONNECTEMPTY */
endmodule

