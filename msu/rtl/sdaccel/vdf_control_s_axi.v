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

module vdf_control_s_axi #(
  parameter integer C_ADDR_WIDTH = 12,
  parameter integer C_DATA_WIDTH = 32
)
(
  // AXI4-Lite slave signals
  input  wire                      aclk             ,
  input  wire                      areset           ,
  input  wire                      aclk_en          ,
  input  wire                      awvalid          ,
  output wire                      awready          ,
  input  wire [C_ADDR_WIDTH-1:0]   awaddr           ,
  input  wire                      wvalid           ,
  output wire                      wready           ,
  input  wire [C_DATA_WIDTH-1:0]   wdata            ,
  input  wire [C_DATA_WIDTH/8-1:0] wstrb            ,
  input  wire                      arvalid          ,
  output wire                      arready          ,
  input  wire [C_ADDR_WIDTH-1:0]   araddr           ,
  output wire                      rvalid           ,
  input  wire                      rready           ,
  output wire [C_DATA_WIDTH-1:0]   rdata            ,
  output wire [2-1:0]              rresp            ,
  output wire                      bvalid           ,
  input  wire                      bready           ,
  output wire [2-1:0]              bresp            ,
  output wire                      interrupt        ,
  output wire                      ap_start         ,
  input  wire                      ap_idle          ,
  input  wire                      ap_done          ,
  // User defined arguments
  output wire [32-1:0]             input0           ,
  output wire [64-1:0]             input_mem        ,
  output wire [64-1:0]             output_mem       ,
  output wire [64-1:0]             intermediates_mem
);

//------------------------Address Info-------------------
// 0x000 : Control signals
//         bit 0  - ap_start (Read/Write/COH)
//         bit 1  - ap_done (Read/COR)
//         bit 2  - ap_idle (Read)
//         others - reserved
// 0x004 : Global Interrupt Enable Register
//         bit 0  - Global Interrupt Enable (Read/Write)
//         others - reserved
// 0x008 : IP Interrupt Enable Register (Read/Write)
//         bit 0  - Channel 0 (ap_done)
//         others - reserved
// 0x00c : IP Interrupt Status Register (Read/TOW)
//         bit 0  - Channel 0 (ap_done)
//         others - reserved
// 0x010 : Data signal of input0
//         bit 31~0 - input0[31:0] (Read/Write)
// 0x014 : reserved
// 0x018 : Data signal of input_mem
//         bit 31~0 - input_mem[31:0] (Read/Write)
// 0x01c : Data signal of input_mem
//         bit 31~0 - input_mem[63:32] (Read/Write)
// 0x020 : Data signal of output_mem
//         bit 31~0 - output_mem[31:0] (Read/Write)
// 0x024 : Data signal of output_mem
//         bit 31~0 - output_mem[63:32] (Read/Write)
// 0x028 : Data signal of intermediates_mem
//         bit 31~0 - intermediates_mem[31:0] (Read/Write)
// 0x02c : Data signal of intermediates_mem
//         bit 31~0 - intermediates_mem[63:32] (Read/Write)
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_AP_CTRL                = 12'h000;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_GIE                    = 12'h004;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_IER                    = 12'h008;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_ISR                    = 12'h00c;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_INPUT0_0               = 12'h010;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_input_mem_0            = 12'h018;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_input_mem_1            = 12'h01c;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_output_mem_0           = 12'h020;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_output_mem_1           = 12'h024;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_intermediates_mem_0    = 12'h028;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_intermediates_mem_1    = 12'h02c;
localparam integer                  LP_SM_WIDTH                    = 2;
localparam [LP_SM_WIDTH-1:0]        SM_WRIDLE                      = 2'd0;
localparam [LP_SM_WIDTH-1:0]        SM_WRDATA                      = 2'd1;
localparam [LP_SM_WIDTH-1:0]        SM_WRRESP                      = 2'd2;
localparam [LP_SM_WIDTH-1:0]        SM_WRRESET                     = 2'd3;
localparam [LP_SM_WIDTH-1:0]        SM_RDIDLE                      = 2'd0;
localparam [LP_SM_WIDTH-1:0]        SM_RDDATA                      = 2'd1;
localparam [LP_SM_WIDTH-1:0]        SM_RDRESET                     = 2'd3;

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
reg  [LP_SM_WIDTH-1:0]              wstate                         = SM_WRRESET;
reg  [LP_SM_WIDTH-1:0]              wnext                         ;
reg  [C_ADDR_WIDTH-1:0]             waddr                         ;
wire [C_DATA_WIDTH-1:0]             wmask                         ;
wire                                aw_hs                         ;
wire                                w_hs                          ;
reg  [LP_SM_WIDTH-1:0]              rstate                         = SM_RDRESET;
reg  [LP_SM_WIDTH-1:0]              rnext                         ;
reg  [C_DATA_WIDTH-1:0]             rdata_r                       ;
wire                                ar_hs                         ;
wire [C_ADDR_WIDTH-1:0]             raddr                         ;
// internal registers
wire                                int_ap_idle                   ;
reg                                 int_ap_done                    = 1'b0;
reg                                 int_ap_start                   = 1'b0;
reg                                 int_gie                        = 1'b0;
reg                                 int_ier                        = 1'b0;
reg                                 int_isr                        = 1'b0;

reg  [32-1:0]                       int_input0                     = 32'd0;
reg  [64-1:0]                       int_input_mem                  = 64'd0;
reg  [64-1:0]                       int_output_mem                 = 64'd0;
reg  [64-1:0]                       int_intermediates_mem          = 64'd0;

///////////////////////////////////////////////////////////////////////////////
// Begin RTL
///////////////////////////////////////////////////////////////////////////////

//------------------------AXI write fsm------------------
assign awready = (wstate == SM_WRIDLE);
assign wready  = (wstate == SM_WRDATA);
assign bresp   = 2'b00;  // OKAY
assign bvalid  = (wstate == SM_WRRESP);
assign wmask   = { {8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}} };
assign aw_hs   = awvalid & awready;
assign w_hs    = wvalid & wready;

// wstate
always @(posedge aclk) begin
  if (areset)
    wstate <= SM_WRRESET;
  else if (aclk_en)
    wstate <= wnext;
end

// wnext
always @(*) begin
  case (wstate)
    SM_WRIDLE:
      if (awvalid)
        wnext = SM_WRDATA;
      else
        wnext = SM_WRIDLE;
    SM_WRDATA:
      if (wvalid)
        wnext = SM_WRRESP;
      else
        wnext = SM_WRDATA;
    SM_WRRESP:
      if (bready)
        wnext = SM_WRIDLE;
      else
        wnext = SM_WRRESP;
    // SM_WRRESET
    default:
      wnext = SM_WRIDLE;
  endcase
end

// waddr
always @(posedge aclk) begin
  if (aclk_en) begin
    if (aw_hs)
      waddr <= awaddr;
  end
end

//------------------------AXI read fsm-------------------
assign arready = (rstate == SM_RDIDLE);
assign rdata   = rdata_r;
assign rresp   = 2'b00;  // OKAY
assign rvalid  = (rstate == SM_RDDATA);
assign ar_hs   = arvalid & arready;
assign raddr   = araddr;

// rstate
always @(posedge aclk) begin
  if (areset)
    rstate <= SM_RDRESET;
  else if (aclk_en)
    rstate <= rnext;
end

// rnext
always @(*) begin
  case (rstate)
    SM_RDIDLE:
      if (arvalid)
        rnext = SM_RDDATA;
      else
        rnext = SM_RDIDLE;
    SM_RDDATA:
      if (rready & rvalid)
        rnext = SM_RDIDLE;
      else
        rnext = SM_RDDATA;
    // SM_RDRESET:
    default:
      rnext = SM_RDIDLE;
  endcase
end

// rdata_r
always @(posedge aclk) begin
  if (aclk_en) begin
    if (ar_hs) begin
      rdata_r <= {C_DATA_WIDTH{1'b0}};
      case (raddr)
        LP_ADDR_AP_CTRL: begin
          rdata_r[0] <= int_ap_start;
          rdata_r[1] <= int_ap_done;
          rdata_r[2] <= int_ap_idle;
          rdata_r[3+:C_DATA_WIDTH-3] <= {C_DATA_WIDTH-3{1'b0}};
        end
        LP_ADDR_GIE: begin
          rdata_r[0] <= int_gie;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_IER: begin
          rdata_r[0] <= int_ier;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_ISR: begin
          rdata_r[0] <= int_isr;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_INPUT0_0: begin
          rdata_r <= int_input0[0+:32];
        end
        LP_ADDR_input_mem_0: begin
          rdata_r <= int_input_mem[0+:32];
        end
        LP_ADDR_input_mem_1: begin
          rdata_r <= int_input_mem[32+:32];
        end
        LP_ADDR_output_mem_0: begin
          rdata_r <= int_output_mem[0+:32];
        end
        LP_ADDR_output_mem_1: begin
          rdata_r <= int_output_mem[32+:32];
        end
        LP_ADDR_intermediates_mem_0: begin
          rdata_r <= int_intermediates_mem[0+:32];
        end
        LP_ADDR_intermediates_mem_1: begin
          rdata_r <= int_intermediates_mem[32+:32];
        end

        default: begin
          rdata_r <= {C_DATA_WIDTH{1'b0}};
        end
      endcase
    end
  end
end

//------------------------Register logic-----------------
assign interrupt    = int_gie & (|int_isr);
assign ap_start     = int_ap_start;
assign int_ap_idle  = ap_idle;
assign input0 = int_input0;
assign input_mem = int_input_mem;
assign output_mem = int_output_mem;
assign intermediates_mem = int_intermediates_mem;

// int_ap_start
always @(posedge aclk) begin
  if (areset)
    int_ap_start <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_AP_CTRL && wstrb[0] && wdata[0])
      int_ap_start <= 1'b1;
    else if (ap_done)
      int_ap_start <= 1'b0;
  end
end

// int_ap_done
always @(posedge aclk) begin
  if (areset)
    int_ap_done <= 1'b0;
  else if (aclk_en) begin
    if (ap_done)
      int_ap_done <= 1'b1;
    else if (ar_hs && raddr == LP_ADDR_AP_CTRL)
      int_ap_done <= 1'b0; // clear on read
  end
end

// int_gie
always @(posedge aclk) begin
  if (areset)
    int_gie     <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_GIE && wstrb[0])
      int_gie <= wdata[0];
  end
end

// int_ier
always @(posedge aclk) begin
  if (areset)
    int_ier     <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_IER && wstrb[0])
      int_ier <= wdata[0];
  end
end

// int_isr
always @(posedge aclk) begin
  if (areset)
    int_isr     <= 1'b0;
  else if (aclk_en) begin
    if (int_ier & ap_done)
      int_isr <= 1'b1;
    else if (w_hs && waddr == LP_ADDR_ISR && wstrb[0])
      int_isr <= int_isr ^ wdata[0];
  end
end


// int_input0[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_input0[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_INPUT0_0)
      int_input0[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_input0[0+:32] & ~wmask[0+:32]);
  end
end

// int_input_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_input_mem[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_input_mem_0)
      int_input_mem[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_input_mem[0+:32] & ~wmask[0+:32]);
  end
end

// int_input_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_input_mem[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_input_mem_1)
      int_input_mem[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_input_mem[32+:32] & ~wmask[0+:32]);
  end
end

// int_output_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_output_mem[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_output_mem_0)
      int_output_mem[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_output_mem[0+:32] & ~wmask[0+:32]);
  end
end

// int_output_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_output_mem[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_output_mem_1)
      int_output_mem[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_output_mem[32+:32] & ~wmask[0+:32]);
  end
end

// int_intermediates_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_intermediates_mem[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_intermediates_mem_0)
      int_intermediates_mem[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_intermediates_mem[0+:32] & ~wmask[0+:32]);
  end
end

// int_intermediates_mem[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_intermediates_mem[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_intermediates_mem_1)
      int_intermediates_mem[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_intermediates_mem[32+:32] & ~wmask[0+:32]);
  end
end


endmodule

`default_nettype wire

