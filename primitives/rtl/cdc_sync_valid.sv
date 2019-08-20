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
   Support sending a data valid signal across clock domains for loading a bus
   using a multi-cycle path.


                           :                                 -----
      <------------------  :                     ---------->|     |
     |                   | :                    |           |     |
     |   -----     ----  | :    ----     ----   |   ----    | XOR |---> out
    --> |     |   | FF | | :   | FF |   | FF |  |  | FF |   |     | 
        | XOR |-->|    |---:-->|    |-->|    |---->|    |-->|     |
 in --> |     |   | /\ |   :   | /\ |   | /\ |     | /\ |   |     |
         -----     ----    :    ----     ----       ----     -----
                     |     :     |        |          |
 clk_in -------------      :      ---------------------------  clk_out

*/

module cdc_sync_valid
   (
    input  logic  clk_in,
    input  logic  clk_out,
    input  logic  rst_in,
    input  logic  rst_out,
    input  logic  valid_in,
    output logic  valid_out
   );

   logic valid_in_xor;
   logic valid_in_pulse;
   logic valid_in_pulse_d1;
   logic valid_in_pulse_d2;
   logic valid_in_pulse_d3;

   always_comb begin
      valid_in_xor = valid_in ^ valid_in_pulse;

      if (rst_in) begin
         valid_in_xor = 1'b0;
      end
   end

   always_ff @(posedge clk_in) begin
      valid_in_pulse <= valid_in_xor;
   end

   always_comb begin
      valid_out = valid_in_pulse_d2 ^ valid_in_pulse_d3;

      if (rst_out) begin
         valid_out   = 1'b0;
      end
   end

   always_ff @(posedge clk_out) begin
      valid_in_pulse_d1 <= valid_in_pulse;
      valid_in_pulse_d2 <= valid_in_pulse_d1;
      valid_in_pulse_d3 <= valid_in_pulse_d2;
   end

endmodule
