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


/*******************************************************************************

 Note: The 3rd and 4th pipestage in each direction is there to provide transit 
       time across the FPGA and is not needed for synchronization.
 
 valid_in and valid_out should be a 1 cycle pulse.
 


        reset                                 valid_out       sq_out
         ext                                     ext            ext
          |                                       ^              ^
          v                                       |              |
         ----                                    ----           ----
        | e1 |                                  | e4 |         | e4 |
         ----                                    ----           ----
          |                                       ^              ^
          v                                       |              |
         ----                                    ----            |  
        | e2 |                                  | e3 |           |   
         ----                                    ----            |  
          |                                       ^              |
          v                                       |              | MCP
         ----     valid_in     sq_in             ----            |  
        | e3 |      ext         ext             | e2 |           |   
         ----        |           |               ----            |  
          |          |------     |                ^              |
          v          v     |     v                |              |
         ----      -----   |    ----             ----            |  
        | e4 |    | cdc |  --->| e1 |           | e1 |           |   
         ----      -----        ----             ----            |  
 clk      |          |            |               |              |
 ext      |       valid_in        |           valid_out          |
          |         int           |              ext             |
          |          |            |               |              |
  ------------------------------------------------------------------------
          |          |            |               ^              ^
          v          v            |               |              |
 clk     ----       ----          |              ----           ----
 int    | i1 |     | i1 |         |             |cdc |  ------>| i1 |
         ----       ----          |              ----   |       ----
          |          |            |               ^     |        ^
          v          v            |               |------        |
         ----       ----          |               |              |
        | i2 |     | i2 |         |          valid_out        sq_out
         ----       ----          |              int            int
          |          |            |   
          v          v            |   
         ----       ----          | MCP
        | i3 |     | i3 |         |   
         ----       ----          |   
          |          |            |   
          v          v            v   
         ----       ----         ---- 
        | i4 |     | i4 |       | i4 |
         ----       ----         ---- 
          |          |            |   
          v          v            v   
        reset     valid_in      sq_in
         int        int          int  
  
*******************************************************************************/

module msu_cdc
   #(
     parameter int MOD_LEN               = `MOD_LEN_DEF,

     parameter int WORD_LEN              = 16,
     parameter int REDUNDANT_ELEMENTS    = 2,
     parameter int NONREDUNDANT_ELEMENTS = MOD_LEN / WORD_LEN,
     parameter int NUM_ELEMENTS          = REDUNDANT_ELEMENTS +
                                           NONREDUNDANT_ELEMENTS,

     parameter int SQ_IN_BITS            = MOD_LEN,
     // Send the coefficients out using 32 bits per ceofficient
     parameter int SQ_OUT_BITS           = NUM_ELEMENTS * WORD_LEN*2
    )
   (
    input logic                    clk_ext,
    input logic                    clk_int,
    input logic                    reset,
    input logic                    valid_in,
    input logic [SQ_IN_BITS-1:0]   sq_in,
    output logic                   valid_out,
    output logic [SQ_OUT_BITS-1:0] sq_out
   );

   // For the Ozturk multiplier, the bitwith of the redundant coefficients.
   localparam int          BIT_LEN               = 17;
   genvar                  j;

   logic                   reset_e1, reset_e2, reset_e3, reset_e4;
   logic                   reset_i1, reset_i2, reset_i3, reset_i4;

   logic                   valid_in_int, valid_in_ext;
   logic                   valid_in_i1, valid_in_i2, valid_in_i3, valid_in_i4;

   logic [SQ_IN_BITS-1:0]  sq_in_e1;
   logic [SQ_IN_BITS-1:0]  sq_in_i4;
   logic [BIT_LEN-1:0]     sq_in_i4_poly[NUM_ELEMENTS];

   logic                   valid_out_int, valid_out_ext;
   logic                   valid_out_e1, valid_out_e2;
   logic                   valid_out_e3, valid_out_e4;

   logic [BIT_LEN-1:0]     sq_out_int_poly[NUM_ELEMENTS];
   logic [SQ_OUT_BITS-1:0] sq_out_int, sq_out_i1;
   logic [SQ_OUT_BITS-1:0] sq_out_e4;


   ////////////////////////////////////////////////////////////////////////
   // External to internal clock transition logic
   ////////////////////////////////////////////////////////////////////////
   
   // Reset is synchronized through flops
   always_ff @(posedge clk_ext) begin
      reset_e1 <= reset;
      reset_e2 <= reset_e1;
      reset_e3 <= reset_e2;
      reset_e4 <= reset_e3;
   end
   always_ff @(posedge clk_int) begin
      reset_i1 <= reset_e4;
      reset_i2 <= reset_i1;
      reset_i3 <= reset_i2;
      reset_i4 <= reset_i3;
   end

   // valid_in goes through a pulse CDC crossing
   cdc_sync_valid valid_in_cdc
     (// Inputs
      .clk_in             (clk_ext),
      .clk_out            (clk_int),
      .rst_in             (reset_e4),
      .rst_out            (reset_i2),
      .valid_in           (valid_in),
      // Outputs
      .valid_out          (valid_in_int)
      );

   // Pipe the valid_in signal
   always_ff @(posedge clk_int) begin
      valid_in_i1 <= valid_in_int;
      valid_in_i2 <= valid_in_i1;
      valid_in_i3 <= valid_in_i2;
      valid_in_i4 <= valid_in_i3;
   end

   // Capture sq_in
   always_ff @(posedge clk_ext) begin
      if(valid_in) begin
         sq_in_e1 <= sq_in;
      end
   end

   // Pipe sq_in - this needs to be set as an MCP
   always_ff @(posedge clk_int) begin
      sq_in_i4 <= sq_in_e1;
   end

   // Split sq_in into polynomial coefficients for Ozturk
   generate 
      for(j = 0; j < NONREDUNDANT_ELEMENTS; j++) begin : sq_in_gen_1
         assign sq_in_i4_poly[j] = {{(BIT_LEN-WORD_LEN){1'b0}},
                                    sq_in_i4[j*WORD_LEN +: WORD_LEN]};
      end
      // Set redundant coefficients to zero
      for(j = NONREDUNDANT_ELEMENTS; j < NUM_ELEMENTS; j++) begin : sq_in_gen_2
         assign sq_in_i4_poly[j] = 0;
      end
   endgenerate


   ////////////////////////////////////////////////////////////////////////
   // Internal to external clock transition logic
   ////////////////////////////////////////////////////////////////////////

   // valid_out goes through a pulse CDC crossing
   cdc_sync_valid valid_out_cdc
     (// Inputs
      .clk_in             (clk_int),
      .clk_out            (clk_ext),
      .rst_in             (reset_i2),
      .rst_out            (reset_e4),
      .valid_in           (valid_out_int),
      // Outputs
      .valid_out          (valid_out_ext)
      );

   // Pipe the valid_out signal
   always_ff @(posedge clk_ext) begin
      valid_out_e1 <= valid_out_ext;
      valid_out_e2 <= valid_out_e1;
      valid_out_e3 <= valid_out_e2;
      valid_out_e4 <= valid_out_e3;
   end
   assign valid_out = valid_out_e4;

   // Capture sq_out
   always_ff @(posedge clk_int) begin
      if(valid_out_int) begin
         sq_out_i1 <= sq_out_int;
      end
   end

   // Pipe sq_out
   always_ff @(posedge clk_ext) begin
      sq_out_e4 <= sq_out_i1;
   end
   assign sq_out = sq_out_e4;

   // Gather the output coefficients into sq_out
   generate
      for(j = 0; j < NUM_ELEMENTS; j++) begin : sq_out_gen
         assign sq_out_int[j*WORD_LEN*2 +: 2*WORD_LEN] = 
                            {{(2*WORD_LEN-BIT_LEN){1'b0}}, sq_out_int_poly[j]};
      end
   endgenerate

   // Instantiate the multiplier
   modular_square_8_cycles 
     #(
       .NONREDUNDANT_ELEMENTS(NONREDUNDANT_ELEMENTS)
       )
   modsqr(
          .clk                (clk_int),
          .reset              (reset_i4),
          .start              (valid_in_i4),
          .sq_in              (sq_in_i4_poly),
          .sq_out             (sq_out_int_poly),
          .valid              (valid_out_int)
          );
endmodule
