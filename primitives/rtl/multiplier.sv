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

/*
  Parameterized width full multiply

              -------       ----
    A    --> |       |     | FF |
             | A * B | --> |    | --> P
    B    --> |       |     | /\ |
              -------       ----
                             ^
    clk  --------------------|


  Can be used to represent an FPGA DSP multiplier for unsigned values
*/

module multiplier
   #(
     parameter int A_BIT_LEN       = 17,
     parameter int B_BIT_LEN       = 17,

     parameter int MUL_OUT_BIT_LEN = A_BIT_LEN + B_BIT_LEN
    )
   (
    input  logic                       clk,
    input  logic [A_BIT_LEN-1:0]       A,
    input  logic [B_BIT_LEN-1:0]       B,
    output logic [MUL_OUT_BIT_LEN-1:0] P
   );

   logic [MUL_OUT_BIT_LEN-1:0] P_result;

   always_comb begin
      P_result[MUL_OUT_BIT_LEN-1:0] = A[A_BIT_LEN-1:0] * B[B_BIT_LEN-1:0];
   end

   always_ff @(posedge clk) begin
      P[MUL_OUT_BIT_LEN-1:0]  <= P_result[MUL_OUT_BIT_LEN-1:0];
   end
endmodule
