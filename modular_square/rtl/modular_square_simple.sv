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
 `define MODULUS_DEF 1024'd435498004454960311370317052397000844802649144205780523913417362625407607066231475209709961473477443808083986632633065072597378881054561793869773671502511117663614834848276234008576433331085414399994150596781014081314102597766163665183768312980812151246986379323231704775209109465985927509514160947756090729;
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

   // Store the square input, circulate the result back to the input
   always_ff @(posedge clk) begin
      if(start) begin
         cur_sq_in <= sq_in;
      end else if(valid) begin
         cur_sq_in <= sq_out_comb;
      end
   end
   assign sq_out = cur_sq_in;

   // Control
   always_ff @(posedge clk) begin
      if(reset) begin
         running <= 0;
         valid_count <= 0;
      end else begin
         if(start || valid) begin
            running <= 1;
            valid_count <= 0;
         end else begin
            valid_count <= valid_count + 1;
         end
      end
   end

   assign valid = running && (valid_count == PIPELINE_DEPTH-1);

   //
   // EDIT HERE
   // Insert/instantiate your multiplier below
   //

   // Compute the modular square function
   // Note verilator fails with a 1024 bit square so this uses a reduced bit
   // size. You will need to increase MOD_LEN in Makefile.simple to 1024 once
   // you implement your multiplier.
   always_comb begin
      squared     = {{MOD_LEN{1'b0}}, cur_sq_in};
      squared     = squared * squared;
      squared     = squared % {{MOD_LEN{1'b0}}, MODULUS};
      sq_out_comb = squared[MOD_LEN-1:0];
   end
endmodule
