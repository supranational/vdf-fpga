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

module tb();
   localparam integer MOD_LEN = 1024;
   //localparam integer MOD_LEN = 128;

   
   logic                   clk;
   logic                   reset;
   logic                   start;
   logic                   valid;
   logic [MOD_LEN-1:0]     modulus;
   logic [MOD_LEN-1:0]     sq_in;
   logic [MOD_LEN-1:0]     sq_out;
   logic [MOD_LEN-1:0]     sq_out_expected;
   logic [MOD_LEN-1:0]     sq_out_actual;

   integer                 t_start;
   integer                 t_final;
   integer                 t_curr;
   
   integer                 test_file;
   integer                 i, ret;
   integer                 cycle_count;
   integer                 error_count;
   
   integer                 total_cycle_count;
   integer                 total_squarings;
   
   modular_square_simple
     #(
       .MOD_LEN(MOD_LEN)
       )
      uut(
          clk,
          reset,
          start,
          sq_in,
          sq_out,
          valid
          );
   
   initial begin
      test_file = $fopen("../../../../../test.txt", "r");
      if(test_file == 0) begin
         $display("test_file handle was NULL");
         $finish;
      end
   end
                
   always begin
      #5 clk = ~clk;
   end
    
   initial begin
      // Reset the design
      clk           = 1'b0;
      reset         = 1'b1;
      sq_in         = 0;
      start         = 1'b0;
      t_start       = 0;
      t_curr        = 0;

      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);

      reset      = 1'b0;

      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);

      // Scan in the modulus and initial value
      $fscanf(test_file, "%x\n", sq_in); 
      @(negedge clk);

      start         = 1'b1;
      @(negedge clk);
      start         = 1'b0;

      // Run the squarer and periodically check results
      error_count   = 0;
      total_cycle_count          = 0;
      total_squarings            = 0;
      while(1) begin
         ret = $fscanf(test_file, "%d, %x\n", t_final, sq_out_expected);
         if(ret != 2) begin
            break;
         end 

         // Run to the next checkpoint specified in the test file
         cycle_count   = 1;
         t_start       = t_curr;
         while(t_curr < t_final) begin
            if(valid == 1'b1) begin
               t_curr        = t_curr + 1;
               sq_out_actual = sq_out;
               total_squarings   = total_squarings + 1;
            end

            @(negedge clk);
            cycle_count = cycle_count + 1;
            total_cycle_count    = total_cycle_count + 1;
         end

         sq_out_actual = sq_out_actual;

         $display("%5d %0.2f %x", t_final, 
                  real'(cycle_count) / real'(t_final - t_start), 
                  sq_out_actual);

         // Check correctness
         if(sq_out_actual !== sq_out_expected) begin
            $display("MISTATCH expected %x", sq_out_expected);
            $display("           actual %x", sq_out_actual);
            error_count = error_count + 1;
            break;
         end
         @(negedge clk);
         total_cycle_count       = total_cycle_count + 1;
      end
      $display("Overall %d cycles, %d squarings, %0.2f cyc/sq", 
               total_cycle_count, total_squarings,
               real'(total_cycle_count) / real'(total_squarings)); 
      if(error_count == 0) begin
         $display("SUCCESS!");
         $finish();
      end
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      $error("FAILURE %d mismatches", error_count);
      $finish();
   end
endmodule

