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

`include "msuconfig.vh"

// Set a default modulus and bitwidth but allow them to be defined 
// externally as well. 
`ifndef MOD_LEN_DEF
`define MOD_LEN_DEF 1024
`endif
`ifndef MODULUS_DEF
 `define MODULUS_DEF 1024'd124066695684124741398798927404814432744698427125735684128131855064976895337309138910015071214657674309443149407457493434579063840841220334555160125016331040933690674569571217337630239191517205721310197608387239846364360850220896772964978569683229449266819903414117058030106528073928633017118689826625594484331
`endif

module modular_square_simple
   #(
     parameter int MOD_LEN = `MOD_LEN_DEF
    )
   (
    input logic                   clk,
    input logic                   reset,
    input logic                   start,
    input logic [MOD_LEN-1:0]     sq_in,
    output logic [MOD_LEN-1:0]    sq_out,
    output logic                  valid
   );

   localparam [MOD_LEN-1:0] MODULUS = `MODULUS_DEF;

   logic [MOD_LEN-1:0]            cur_sq_in;
   logic [MOD_LEN*2-1:0]          squared;
   logic [MOD_LEN-1:0]            sq_out_comb;

   // Mimic a pipeline
   localparam  [3:0]              PIPELINE_DEPTH = 10;
   logic [3:0]                    valid_count;
   logic                          running;
   logic                          valid_next;

   // Store the square input, circulate the result back to the input
   always_ff @(posedge clk) begin
      if(start) begin
         cur_sq_in <= sq_in;
      end else if(valid_next) begin
         cur_sq_in <= sq_out_comb;
      end
   end
   assign sq_out = valid ? cur_sq_in : {MOD_LEN{1'bx}};

   // Control
   always_ff @(posedge clk) begin
      if(reset) begin
         running        <= 0;
         valid_count    <= 0;
      end else begin
         if(start || valid_next) begin
            running     <= 1;
            valid_count <= 0;
         end else begin
            valid_count <= valid_count + 1;
         end
      end
   end
   
   assign valid_next = running && (valid_count == PIPELINE_DEPTH-1);
   always_ff @(posedge clk) begin
      valid <= valid_next;
   end

   //----------------------------------------------------------------------
   // EDIT HERE
   // Insert/instantiate your multiplier below
   // Modify control above as needed while satisfying the interface
   //

   // Compute the modular square function
   always_comb begin
      squared     = {{MOD_LEN{1'b0}}, cur_sq_in};
      squared     = squared * squared;
      squared     = squared % {{MOD_LEN{1'b0}}, MODULUS};
      sq_out_comb = squared[MOD_LEN-1:0];
   end

   // EDIT HERE
   //----------------------------------------------------------------------

endmodule
