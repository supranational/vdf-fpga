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

// This module implements code that will be inferred by Vivado as a URAM.

module uram 
  #(
    parameter ADDR_LEN = 9,
    parameter DATA_LEN = 72
    ) ( 
        input                     clk,
        input                     we,
        input [DATA_LEN-1:0]      din,
        input [ADDR_LEN-1:0]      addr,
        output reg [DATA_LEN-1:0] dout
        );

   (* ram_style = "ultra" *)
   logic [DATA_LEN-1:0]           mem[(1<<ADDR_LEN)-1:0];
   
   always @ (posedge clk) begin
      if(we) begin
         mem[addr] <= din;
      end
      dout <= mem[addr];
   end
endmodule
