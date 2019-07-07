// /*******************************************************************************
// Copyright (c) 2018, Xilinx, Inc.
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// 
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// 
// 
// 3. Neither the name of the copyright holder nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
// 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// *******************************************************************************/

// default_nettype of none prevents implicit wire declaration.
`default_nettype none
module vdf_wrapper #(
  parameter integer C_M00_AXI_ADDR_WIDTH = 64 ,
  parameter integer C_M00_AXI_DATA_WIDTH = 512
)
(
  // System Signals
  input  wire                              ap_clk           ,
  input  wire                              ap_rst_n         ,
  // AXI4 master interface m00_axi
  output wire                              m00_axi_awvalid  ,
  input  wire                              m00_axi_awready  ,
  output wire [C_M00_AXI_ADDR_WIDTH-1:0]   m00_axi_awaddr   ,
  output wire [8-1:0]                      m00_axi_awlen    ,
  output wire                              m00_axi_wvalid   ,
  input  wire                              m00_axi_wready   ,
  output wire [C_M00_AXI_DATA_WIDTH-1:0]   m00_axi_wdata    ,
  output wire [C_M00_AXI_DATA_WIDTH/8-1:0] m00_axi_wstrb    ,
  output wire                              m00_axi_wlast    ,
  input  wire                              m00_axi_bvalid   ,
  output wire                              m00_axi_bready   ,
  output wire                              m00_axi_arvalid  ,
  input  wire                              m00_axi_arready  ,
  output wire [C_M00_AXI_ADDR_WIDTH-1:0]   m00_axi_araddr   ,
  output wire [8-1:0]                      m00_axi_arlen    ,
  input  wire                              m00_axi_rvalid   ,
  output wire                              m00_axi_rready   ,
  input  wire [C_M00_AXI_DATA_WIDTH-1:0]   m00_axi_rdata    ,
  input  wire                              m00_axi_rlast    ,
  // SDx Control Signals
  input  wire                              ap_start         ,
  output wire                              ap_idle          ,
  output wire                              ap_done          ,
  input  wire [32-1:0]                     input0           ,
  input  wire [64-1:0]                     input_mem        ,
  input  wire [64-1:0]                     output_mem       ,
  input  wire [64-1:0]                     intermediates_mem
);


timeunit 1ps;
timeprecision 1ps;

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////
// Large enough for interesting traffic.
localparam integer  LP_DEFAULT_LENGTH_IN_BYTES = (C_M00_AXI_DATA_WIDTH/8*20);
localparam integer  LP_NUM_EXAMPLES    = 1;

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
(* KEEP = "yes" *)
logic                                areset                         = 1'b0;
logic                                ap_start_r                     = 1'b0;
logic                                ap_idle_r                      = 1'b1;
logic                                ap_start_pulse                ;
logic [LP_NUM_EXAMPLES-1:0]          ap_done_i                     ;
logic [LP_NUM_EXAMPLES-1:0]          ap_done_r                      = {LP_NUM_EXAMPLES{1'b0}};
logic [32-1:0]                       ctrl_constant                  = 32'd1;

///////////////////////////////////////////////////////////////////////////////
// Begin RTL
///////////////////////////////////////////////////////////////////////////////

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

// create pulse when ap_start transitions to 1
always @(posedge ap_clk) begin
  begin
    ap_start_r <= ap_start;
  end
end

assign ap_start_pulse = ap_start & ~ap_start_r;

// ap_idle is asserted when done is asserted, it is de-asserted when ap_start_pulse
// is asserted
always @(posedge ap_clk) begin
  if (areset) begin
    ap_idle_r <= 1'b1;
  end
  else begin
    ap_idle_r <= ap_done ? 1'b1 :
      ap_start_pulse ? 1'b0 : ap_idle;
  end
end

assign ap_idle = ap_idle_r;

// Done logic
always @(posedge ap_clk) begin
  if (areset) begin
    ap_done_r <= '0;
  end
  else begin
    ap_done_r <= (ap_start_pulse | ap_done) ? '0 : ap_done_r | ap_done_i;
  end
end

assign ap_done = &ap_done_r;

// Vadd example
vdf_kernel #(
  .C_M_AXI_ADDR_WIDTH ( C_M00_AXI_ADDR_WIDTH ),
  .C_M_AXI_DATA_WIDTH ( C_M00_AXI_DATA_WIDTH ),
  .C_ADDER_BIT_WIDTH  ( 32                   ),
  .C_XFER_SIZE_WIDTH  ( 32                   )
)
inst_kernel (
  .aclk                    ( ap_clk                  ),
  .areset                  ( areset                  ),
  .kernel_clk              ( ap_clk                  ),
  .kernel_rst              ( areset                  ),
  .ctrl_addr_offset_in     ( input_mem               ),
  .ctrl_addr_offset_out    ( output_mem              ),
  .ctrl_constant           ( 32'b1                   ),
  .ap_start                ( ap_start_pulse          ),
  .ap_done                 ( ap_done_i[0]            ),
  .m_axi_awvalid           ( m00_axi_awvalid         ),
  .m_axi_awready           ( m00_axi_awready         ),
  .m_axi_awaddr            ( m00_axi_awaddr          ),
  .m_axi_awlen             ( m00_axi_awlen           ),
  .m_axi_wvalid            ( m00_axi_wvalid          ),
  .m_axi_wready            ( m00_axi_wready          ),
  .m_axi_wdata             ( m00_axi_wdata           ),
  .m_axi_wstrb             ( m00_axi_wstrb           ),
  .m_axi_wlast             ( m00_axi_wlast           ),
  .m_axi_bvalid            ( m00_axi_bvalid          ),
  .m_axi_bready            ( m00_axi_bready          ),
  .m_axi_arvalid           ( m00_axi_arvalid         ),
  .m_axi_arready           ( m00_axi_arready         ),
  .m_axi_araddr            ( m00_axi_araddr          ),
  .m_axi_arlen             ( m00_axi_arlen           ),
  .m_axi_rvalid            ( m00_axi_rvalid          ),
  .m_axi_rready            ( m00_axi_rready          ),
  .m_axi_rdata             ( m00_axi_rdata           ),
  .m_axi_rlast             ( m00_axi_rlast           ),
  .input0                  ( input0                  )
);


endmodule : vdf_wrapper
`default_nettype wire
