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

module modular_square_wrapper
   #(
     parameter int REDUNDANT_ELEMENTS    = 2,
     parameter int NONREDUNDANT_ELEMENTS = 8,
     parameter int NUM_SEGMENTS          = 4,
     parameter int BIT_LEN               = 17,
     parameter int WORD_LEN              = 16,
     parameter int REDUCTION_DIN_LEN     = 32,

     parameter int NUM_ELEMENTS          = REDUNDANT_ELEMENTS +
                                           NONREDUNDANT_ELEMENTS
    )
   (
    input  logic                clk,
    input  logic                rst,
    input  logic                start,
    input  logic [BIT_LEN-1:0]  sq_in[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0]  sq_out[NUM_ELEMENTS],
    output logic                valid,

    input                         reduction_we,
    input [REDUCTION_DIN_LEN-1:0] reduction_din,
    input                         reduction_din_valid
   );

   localparam int IO_STAGES   = 3;

   logic               start_stages[IO_STAGES];
   logic [BIT_LEN-1:0] sq_in_stages[IO_STAGES][NUM_ELEMENTS];
   logic [BIT_LEN-1:0] sq_out_stages[IO_STAGES][NUM_ELEMENTS];
   logic               valid_stages[IO_STAGES];

   genvar              j;
   always_ff @(posedge clk) begin
      start_stages[0]     <= start;
      sq_in_stages[0]     <= sq_in;
   end
   assign sq_out = sq_out_stages[IO_STAGES-1];
   assign valid  = valid_stages[IO_STAGES-1];

   generate
      for(j = 1; j < IO_STAGES; j++) begin
         always_ff @(posedge clk) begin
            start_stages[j]  <= start_stages[j-1];
            sq_in_stages[j]  <= sq_in_stages[j-1];
            sq_out_stages[j] <= sq_out_stages[j-1];
            valid_stages[j]  <= valid_stages[j-1];
         end
      end
   endgenerate

   modular_square_8_cycles 
     #(
       .REDUNDANT_ELEMENTS(REDUNDANT_ELEMENTS),
       .NONREDUNDANT_ELEMENTS(NONREDUNDANT_ELEMENTS),
       .BIT_LEN(BIT_LEN),
       .WORD_LEN(WORD_LEN),
       .REDUCTION_DIN_LEN(REDUCTION_DIN_LEN)
       )
   modsqr(
          .clk                (clk),
          .rst                (rst),
          .start              (start_stages[IO_STAGES-1]),
          .sq_in              (sq_in_stages[IO_STAGES-1]),
          .sq_out             (sq_out_stages[0]),
          .valid              (valid_stages[0]),
          .reduction_we       (reduction_we),
          .reduction_din      (reduction_din[REDUCTION_DIN_LEN-1:0]),
          .reduction_din_valid(reduction_din_valid)
          );

endmodule
