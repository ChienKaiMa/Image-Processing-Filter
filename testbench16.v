`timescale 1ns/10ps
`define CYCLE     10.0          	     // Modify your clock period here
`define End_CYCLE 1000000                // Modify cycle times once your design need more cycle times!
`define IMAGE_PAT "./image_16x16.dat"
`define LCU_PAT   "./lcu_16x16.dat"
`define EXP       "./golden_16x16.dat"
`define LCU_SIZE  0
`define DEL       1

module test;

parameter IMAGE_NUM  = 128*128;
parameter size       = 16;
parameter size_sqr   = size*size;
parameter block      = 128/16;

reg   clk ;
reg   reset ;
reg   in_en;
reg   [7:0]  din;
reg   [1:0]  ipf_type;
reg   [4:0]  ipf_band_pos;
reg          ipf_wo_class;
reg   [15:0] ipf_offset;
reg   [2:0]  lcu_x, lcu_y;
reg   [3:0]  lcu_x_p, lcu_y_p;
reg   [1:0]  lcu_size;
wire  busy;
wire  finish;
wire  out_en;
wire  [7:0]  dout;
wire  [13:0]  dout_addr;

reg   [7:0]   image_mem   [0:IMAGE_NUM-1];
reg   [23:0]  lcu_mem     [0:size_sqr-1];
reg   [7:0]   exp_mem     [0:IMAGE_NUM-1];
reg   [7:0]   test_mem    [0:IMAGE_NUM-1];
integer       a, b, x, y, err, pass;
reg   [6:0]   n, n_p;
reg   [13:0]  i; 
reg   [14:0]  i_p;
reg           over;
reg   [13:0]  addr;


IPF IPF( .clk          (clk), 
         .reset        (reset), 
         .in_en        (in_en), 
         .din          (din), 
         .ipf_type     (ipf_type), 
         .ipf_band_pos (ipf_band_pos), 
         .ipf_wo_class (ipf_wo_class), 
         .ipf_offset   (ipf_offset), 
         .lcu_x        (lcu_x), 
         .lcu_y        (lcu_y), 
         .lcu_size     (lcu_size), 
         .busy         (busy), 
         .out_en       (out_en),
         .dout         (dout),
         .dout_addr    (dout_addr),
         .finish       (finish)
         );
   
initial	$readmemh (`IMAGE_PAT, image_mem);
initial	$readmemb (`LCU_PAT, lcu_mem);
initial	$readmemh (`EXP, exp_mem);

initial begin
   clk           = 1'b0;
   reset         = 1'b0;
   in_en         = 1'b0;
   din           = 0;
   ipf_type      = 'hz;
   ipf_band_pos  = 'hz;
   ipf_wo_class  = 'hz;
   ipf_offset    = 16'b0; 
   lcu_x         = 0;
   lcu_x_p       = 0;
   lcu_y         = 0;
   lcu_y_p       = 0;
   lcu_size      = `LCU_SIZE;
   i             = 0;
   i_p           = 0;
   n             = 0;
   n_p           = 0;
   a             = 0;
   b             = 0;
   x             = 0;
   y             = 0;
   addr          = 0;
   err           = 0;
   pass          = 0;
   over          = 0;
end

always begin #(`CYCLE/2) clk = ~clk; end

initial begin
   `ifdef SDFSYN
     $sdf_annotate("IPF_syn.sdf", IPF);
   `endif
   `ifdef SDFAPR
     $sdf_annotate("IPF_APR.sdf", IPF);
   `endif	 	 
   `ifdef FSDB
     $fsdbDumpfile("IPF.fsdb");
     $fsdbDumpvars(0,test,"+mda");
   `endif
   `ifdef VCD
     $dumpfile("IPF.vcd");
	 $dumpvars();
   `endif
end

initial begin
   @(posedge clk)  #`DEL  reset = 1'b1;
   #`CYCLE                reset = 1'b0;    
   
   @(posedge clk) ;
    while (i_p < IMAGE_NUM) begin
      if(!busy)begin
         #`DEL;
         i=i_p;
         n=n_p;
         lcu_x=lcu_x_p;
         lcu_y=lcu_y_p;
         
         din   = image_mem[i];
         in_en = 1'b1;
         if((i!=0) &&(i % (size_sqr*(n+1)-1))==0) begin n_p = n_p+1;       lcu_x_p= lcu_x_p+1;  end  
         if(lcu_x_p > block-1)                    begin lcu_y_p=lcu_y_p+1; lcu_x_p= 0;          end
         if(lcu_y_p > block-1)                    begin lcu_x_p=block-1;   lcu_y_p= block-1;    end
         
         ipf_type     = lcu_mem[n][23:22];
         ipf_band_pos = lcu_mem[n][21:17];
         ipf_wo_class = lcu_mem[n][16];
         ipf_offset   = lcu_mem[n][15:0];
         i_p= i_p+1;     
      end
      @(posedge clk);  
    end     
    #`DEL in_en = 1'b0;  din=8'hz;    $display("Send Data Over!");
end

//integer outfile;
//initial begin
//   outfile = $fopen("result_16x16.dat");
//end

//always @(posedge finish) begin
//   if(finish)begin      
//      for (a=0; a<IMAGE_NUM; a=a+1)begin
//	      $fdisplay(outfile, "%h              //Mem[%5d] = %d", test_mem[a],a,test_mem[a]);
//	  end
//   end
//end

always @(negedge clk) begin
   if(out_en)begin
      test_mem[dout_addr] = dout;
   end
end

always @(posedge finish)begin
   if(finish)begin
      $display("Begin to Check OUTPUT Data....");
      $display("-----------------------------------------------------\n");      
      for (a=0; a<block; a=a+1)begin
         for (b=0; b<block; b=b+1)begin                     
            for (y=0; y<size; y=y+1)begin     
               for (x=0; x<size; x=x+1)begin
                  addr=(y*128+x)+(128*size*a+b*size);
                  if(test_mem[addr] !== exp_mem[addr])begin                  
                     $display("Address:%5d => LCU(lcu_y=%2d, lcu_x=%2d): ERROR at Pixel(y=%2d, x=%2d): %2h !=expect %2h ",addr, a, b, y, x, test_mem[addr], exp_mem[addr]);
                     err = err + 1 ;  
                  end            
                  else begin      
                     pass = pass + 1 ;
                  end                              
               end                  
            end                                          
         end
      end                             
      over=1;            
   end                                             
end



initial  begin
 #(`CYCLE * `End_CYCLE);   
 $display("-----------------------------------------------------\n");
 $display("Error!!! Somethings' wrong with your code ...!\n");
 $display("Perhaps you can adjust the bigger value of End_CYCLE and then run the simulation again!");
 $display("-------------------------FAIL------------------------\n");
 $display("-----------------------------------------------------\n"); 
 $finish;
end

initial begin
      @(posedge over)      
      if((over)  && (pass !== 'd0) ) begin
         if (err == 0)  begin
            $display("============================================================================");
            $display("\n");
            $display("        *************************************************              ");
            $display("        **                                             **       /|__/|");
            $display("        **             Congratulations !!              **      / O,O  \\");
            $display("        **                                             **     /_____   \\");
            $display("        **       All data have passed the test!        **    /^ ^ ^ \\  |");
            $display("        **                                             **   |^ ^ ^ ^ |w|");              
            $display("        **                                             **    \\ ^ ^ ^ |w|");
            $display("        *************************************************     \\m__m__|_|");
            $display("\n");
            $display("============================================================================");
         end
         else begin
            $display("-----------------------------------------------------\n");
            $display("There are %d errors!\n", err);
            $display("-----------------------------------------------------\n");
         end
      end
      #(`CYCLE/2);
	  $finish;
end
   
endmodule

