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

module multiply_diff_widths
   #(
     parameter int NUM_ELEMENTS    = 34,
     parameter int LG_BIT_LEN      = 26,
     parameter int BIT_LEN         = 17,
     parameter int LG_WORD_LEN     = 25,
     parameter int WORD_LEN        = 16,
     parameter int OUT_BIT_LEN     = WORD_LEN + $clog2(NUM_ELEMENTS*2)
    )
   (
    input  logic                       clk,
    input  logic [BIT_LEN-1:0]         A[NUM_ELEMENTS],
    input  logic [BIT_LEN-1:0]         B[NUM_ELEMENTS],
    output logic [OUT_BIT_LEN-1:0]     Cout[(NUM_ELEMENTS*2)+1],
    output logic [OUT_BIT_LEN-1:0]     S[(NUM_ELEMENTS*2)+1]
   );

   localparam int MUL_OUT_BIT_LEN  = LG_BIT_LEN + BIT_LEN;
   localparam int GRID_PAD         = OUT_BIT_LEN - WORD_LEN;

   //localparam int LG_NUM_ELEMENTS  = int'($ceil((NUM_ELEMENTS*WORD_LEN) /
   //                                             LG_WORD_LEN));
   localparam int LG_NUM_ELEMENTS  = ((NUM_ELEMENTS*WORD_LEN)+(LG_WORD_LEN-1))/
                                     LG_WORD_LEN;

   function int total_grid_rows;
      total_grid_rows = 0;
      for (int k=0; k<LG_NUM_ELEMENTS; k=k+1) begin
         if ((MUL_OUT_BIT_LEN - (WORD_LEN*2)) > 
             (WORD_LEN - ((k*(LG_WORD_LEN-WORD_LEN)) % WORD_LEN))) begin
            total_grid_rows += 4;
         end
         else begin
            total_grid_rows += 3;
         end
      end
   endfunction

   function int total_grid_cols;
      total_grid_cols = (((LG_NUM_ELEMENTS-1) * LG_WORD_LEN) / WORD_LEN);
      if ((WORD_LEN - (((LG_NUM_ELEMENTS-1)*(LG_WORD_LEN-WORD_LEN)) 
                       % WORD_LEN)) < (MUL_OUT_BIT_LEN - (WORD_LEN*2))) begin 
         total_grid_cols += 4;
      end
      else begin
         total_grid_cols += 3;
      end
      total_grid_cols += (NUM_ELEMENTS-1);
   endfunction

   function int get_grid_row(int index);
      get_grid_row = 0;
      if (index > 0) begin
         for (int k=0; k<index; k=k+1) begin
            if ((MUL_OUT_BIT_LEN-(WORD_LEN*2)) > 
                (WORD_LEN-((k*(LG_WORD_LEN-WORD_LEN))%WORD_LEN))) begin
               get_grid_row += 4;
            end
            else begin
               get_grid_row += 3;
            end
         end
      end
   endfunction

   function int get_grid_third_u(int offset);
      if ((((WORD_LEN*3)-1) - offset) >= MUL_OUT_BIT_LEN) begin
         get_grid_third_u = MUL_OUT_BIT_LEN-1;
      end
      else begin
         get_grid_third_u = ((WORD_LEN*3)-1) - offset;
      end
   endfunction

   function int get_grid_third_z(int offset);
      if ((((WORD_LEN*3)-1) - offset) >= MUL_OUT_BIT_LEN) begin
         get_grid_third_z = ((WORD_LEN*3) - MUL_OUT_BIT_LEN) - offset;
      end
      else begin
         get_grid_third_z = 0;
      end
   endfunction

   function int get_grid_fourth_l(int offset);
      if (((WORD_LEN*3) - offset) >= MUL_OUT_BIT_LEN) begin
         // Will never happen, blocked by if in grid setting block
         get_grid_fourth_l = MUL_OUT_BIT_LEN-1; 
      end
      else begin
         get_grid_fourth_l = (WORD_LEN*3) - offset;
      end
   endfunction

   function int get_grid_fourth_z(int offset);
      if (((WORD_LEN*3) - offset) >= MUL_OUT_BIT_LEN) begin
         get_grid_fourth_z = 15;
      end
      else begin
         get_grid_fourth_z = ((WORD_LEN*4) - MUL_OUT_BIT_LEN) - offset;
      end
   endfunction

   logic [MUL_OUT_BIT_LEN-1:0] mul_result[LG_NUM_ELEMENTS*NUM_ELEMENTS]; 

   logic [LG_BIT_LEN-1:0]      A_large[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      first_word[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      second_word[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      third_word[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      or_first[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      or_sec[LG_NUM_ELEMENTS];
   logic [LG_BIT_LEN-1:0]      or_prev[LG_NUM_ELEMENTS];

   logic [OUT_BIT_LEN-1:0]     grid[total_grid_cols()][total_grid_rows()]; 

   genvar i, j;
   generate
      for (i=0; i<LG_NUM_ELEMENTS; i++) begin : poly_conv
         localparam int OFFSET = ((i*(LG_WORD_LEN-WORD_LEN))%WORD_LEN);
         localparam int INDEX  = int'((i*LG_WORD_LEN)/WORD_LEN);

         always_comb begin
            first_word[i]  = '0; 
            second_word[i] = '0; 
            third_word[i]  = '0; 
            or_first[i]    = '0;
            or_sec[i]      = '0;
            or_prev[i]     = '0;

            // May need to add in carry from previous word if exact fit
            if ((i != 0) && (OFFSET == 0)) begin
               or_prev[i][((BIT_LEN-WORD_LEN)-1):0] = 
                  A[INDEX-1][(BIT_LEN-1):WORD_LEN];
            end
            
            first_word[i][BIT_LEN-1:0] = 
               ((A[INDEX] >> OFFSET) & 
                ((2**(WORD_LEN - OFFSET))-1));
         
            // First word carry bit to add in
            or_first[i][(BIT_LEN-OFFSET)-1:WORD_LEN-OFFSET] = 
               A[INDEX][(BIT_LEN-1):WORD_LEN];

            // If second word available
            if ((INDEX+1) < NUM_ELEMENTS) begin
               // Full second word
               if ((LG_WORD_LEN-WORD_LEN) >= (WORD_LEN-OFFSET)) begin
                  second_word[i][LG_BIT_LEN-1:0] = 
                     {{(LG_BIT_LEN-WORD_LEN){1'b0}}, 
                      A[INDEX+1][WORD_LEN-1:0]}
                     << (WORD_LEN - OFFSET);
               end
               // Partial second word
               else begin
                  second_word[i][LG_BIT_LEN-1:0] = 
                     ({{(LG_BIT_LEN-BIT_LEN){1'b0}}, A[INDEX+1]} & 
                      ((2**(LG_WORD_LEN-(WORD_LEN-OFFSET)))-1))
                     << (WORD_LEN - OFFSET);
               end
            end

            // If third word is required and available 
            if ((((WORD_LEN*2) - OFFSET) < LG_WORD_LEN) &&
                ((INDEX+2) < NUM_ELEMENTS)) begin
               // Second word carry bit to add in
               logic [LG_BIT_LEN-1:0]      last_shift;
               last_shift = ({{(LG_BIT_LEN-BIT_LEN){1'b0}}, A[INDEX+1]}
                             << (WORD_LEN-OFFSET));
               or_sec[i] = last_shift & (2**((WORD_LEN*2) - OFFSET));

               // Partial third word
               third_word[i][LG_BIT_LEN-1:0] = 
                  ({{(LG_BIT_LEN-BIT_LEN){1'b0}}, A[INDEX+2]} & 
                   ((2**(LG_WORD_LEN-((WORD_LEN*2)-OFFSET)))-1))
                  << ((WORD_LEN*2) - OFFSET);
            end
            // Last element, add in carry bit
            else if ((i == (LG_NUM_ELEMENTS-1)) & 
                     ((INDEX+1) < NUM_ELEMENTS)) begin
               logic [LG_BIT_LEN-1:0]      last_shift;
               last_shift = ({{(LG_BIT_LEN-BIT_LEN){1'b0}}, A[INDEX+1]}
                             << (WORD_LEN-OFFSET));
               or_sec[i] = last_shift & (2**((WORD_LEN*2) - OFFSET));
            end
   
            A_large[i] = (first_word[i] | second_word[i] | third_word[i]) +
                         (or_first[i]   | or_sec[i]      | or_prev[i]);
         end
      end
   endgenerate


   // Instantiate all the multipliers, requires NUM_ELEMENTS^2 muls
   generate
      for (i=0; i<LG_NUM_ELEMENTS; i=i+1) begin : mul_A
         for (j=0; j<NUM_ELEMENTS; j=j+1) begin : mul_B
            multiplier #(.A_BIT_LEN(LG_BIT_LEN),
                         .B_BIT_LEN(BIT_LEN)
                        ) multiplier (
                                      .clk(clk),
                                      .A(A_large[i][LG_BIT_LEN-1:0]),
                                      .B(B[j][BIT_LEN-1:0]),
                                      .P(mul_result[(NUM_ELEMENTS*i)+j])
                                     );
         end
      end
   endgenerate

   generate
      for (i=0; i<LG_NUM_ELEMENTS; i=i+1) begin : grid_large
         localparam int CURR_GRID_OFFSET = (i*(LG_WORD_LEN-WORD_LEN))%WORD_LEN;
         localparam int CURR_GRID_INDEX  = int'((i*LG_WORD_LEN)/WORD_LEN);
         localparam int CURR_GRID_ROW    = get_grid_row(i);

         localparam int FIRST_U          = ((WORD_LEN)-1) - CURR_GRID_OFFSET;
         localparam int FIRST_L          = 0;
         localparam int FIRST_Z          = CURR_GRID_OFFSET;

         localparam int SECOND_U         = ((WORD_LEN*2)-1) - CURR_GRID_OFFSET;
         localparam int SECOND_L         = (WORD_LEN - CURR_GRID_OFFSET);

         localparam int THIRD_U          = get_grid_third_u(CURR_GRID_OFFSET);
         localparam int THIRD_L          = ((WORD_LEN*2) - CURR_GRID_OFFSET);
         localparam int THIRD_Z          = get_grid_third_z(CURR_GRID_OFFSET);

         localparam int FOURTH_U         = MUL_OUT_BIT_LEN - 1;
         localparam int FOURTH_L         = get_grid_fourth_l(CURR_GRID_OFFSET);
         localparam int FOURTH_Z         = get_grid_fourth_z(CURR_GRID_OFFSET);

         // Set unused grid locations to 0
         // Pre is bottom left side of parallelogram, post is the upper right
         for (j=0; j<CURR_GRID_INDEX; j=j+1) begin : grid_init_0_pre
            always_comb begin
               grid[j][CURR_GRID_ROW] = '0;
            end 
         end

         for (j=CURR_GRID_INDEX+NUM_ELEMENTS; j<total_grid_cols(); 
              j=j+1) begin : grid_init_0_post
            always_comb begin
               grid[j][CURR_GRID_ROW] = '0;
            end 
         end

         for (j=0; j<CURR_GRID_INDEX+1; j=j+1) begin : grid_init_1_pre
            always_comb begin
               grid[j][CURR_GRID_ROW+1] = '0;
            end 
         end

         for (j=CURR_GRID_INDEX+NUM_ELEMENTS+1; j<total_grid_cols(); 
              j=j+1) begin : grid_init_1_post
            always_comb begin
               grid[j][CURR_GRID_ROW+1] = '0;
            end 
         end

         for (j=0; j<CURR_GRID_INDEX+2; j=j+1) begin : grid_init_2_pre
            always_comb begin
               grid[j][CURR_GRID_ROW+2] = '0;
            end 
         end

         for (j=CURR_GRID_INDEX+NUM_ELEMENTS+2; j<total_grid_cols(); 
              j=j+1) begin : grid_init_2_post
            always_comb begin
               grid[j][CURR_GRID_ROW+2] = '0;
            end 
         end

         if ((MUL_OUT_BIT_LEN-(WORD_LEN*2)) > (WORD_LEN-CURR_GRID_OFFSET)) begin
            for (j=0; j<CURR_GRID_INDEX+3; j=j+1) begin : grid_init_3_pre
               always_comb begin
                  grid[j][CURR_GRID_ROW+3] = '0;
               end 
            end

            for (j=CURR_GRID_INDEX+NUM_ELEMENTS+3; j<total_grid_cols(); 
                 j=j+1) begin : grid_init_3_post
               always_comb begin
                  grid[j][CURR_GRID_ROW+3] = '0;
               end 
            end
         end

         for (j=0; j<NUM_ELEMENTS; j=j+1) begin : grid_small
            always_comb begin
               grid[CURR_GRID_INDEX+j][CURR_GRID_ROW] = 
                  {{GRID_PAD{1'b0}}, 
                   mul_result[(i*NUM_ELEMENTS)+j][FIRST_U:FIRST_L], 
                   {FIRST_Z{1'b0}}};

               grid[CURR_GRID_INDEX+j+1][CURR_GRID_ROW+1] = 
                  {{GRID_PAD{1'b0}}, 
                   mul_result[(i*NUM_ELEMENTS)+j][SECOND_U:SECOND_L]};

               grid[CURR_GRID_INDEX+j+2][CURR_GRID_ROW+2] = 
                  {{(GRID_PAD + THIRD_Z){1'b0}}, 
                   mul_result[(i*NUM_ELEMENTS)+j][THIRD_U:THIRD_L]};

               if ((MUL_OUT_BIT_LEN-(WORD_LEN*2)) > 
                   (WORD_LEN-CURR_GRID_OFFSET)) begin
                  grid[CURR_GRID_INDEX+j+3][CURR_GRID_ROW+3] = 
                     {{(GRID_PAD + FOURTH_Z){1'b0}}, 
                      mul_result[(i*NUM_ELEMENTS)+j][FOURTH_U:FOURTH_L]};
               end
            end
         end
      end
   endgenerate

   // Sum each column using compressor tree
   generate
      // The first and last columns have only one entry, return in S
      always_ff @(posedge clk) begin
         Cout[0][OUT_BIT_LEN-1:0]                   <= '0;
         Cout[total_grid_cols()-1][OUT_BIT_LEN-1:0] <= '0;

         S[0][OUT_BIT_LEN-1:0]                      <= 
            grid[0][0][OUT_BIT_LEN-1:0];

         S[total_grid_cols()-1][OUT_BIT_LEN-1:0]    <= 
            grid[total_grid_cols()-1][total_grid_rows()-1][OUT_BIT_LEN-1:0];
      end

      // Loop through grid parallelogram
      // The number of elements increases up to the midpoint then decreases
      // Starting grid row is 0 for the first half, decreases by 2 thereafter
      // Instantiate compressor tree per column
      for (i=1; i<total_grid_cols()-1; i=i+1) begin : col_sums
         // TODO - send row subset to compressor as before?
/*
         localparam integer CUR_ELEMENTS = (i < NUM_ELEMENTS) ? 
                                              ((i*2)+1) :
                                              ((NUM_ELEMENTS*4) - 1 - (i*2));
         localparam integer GRID_INDEX   = (i < NUM_ELEMENTS) ? 
                                              0 :
                                              (((i - NUM_ELEMENTS) * 2) + 1);
*/

         logic [OUT_BIT_LEN-1:0] Cout_col;
         logic [OUT_BIT_LEN-1:0] S_col; 

         //compressor_tree_3_to_2 #(.NUM_ELEMENTS(CUR_ELEMENTS),
         compressor_tree_3_to_2 #(.NUM_ELEMENTS(total_grid_rows()),
                                  .BIT_LEN(OUT_BIT_LEN)
                                 )
            compressor_tree_3_to_2 (
               //.terms(grid[i][GRID_INDEX:(GRID_INDEX + CUR_ELEMENTS - 1)]),
               .terms(grid[i]),
               .C(Cout_col),
               .S(S_col)
            );

         always_ff @(posedge clk) begin
            Cout[i][OUT_BIT_LEN-1:0] <= Cout_col[OUT_BIT_LEN-1:0];
            S[i][OUT_BIT_LEN-1:0]    <= S_col[OUT_BIT_LEN-1:0];
         end
      end
   endgenerate
endmodule
