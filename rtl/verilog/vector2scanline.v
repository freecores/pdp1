`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yann Vernier
// 
// Create Date:    21:37:32 02/19/2011 
// Design Name: 
// Module Name:    vector2scanline 
// Project Name: PDP-1
// Target Devices: Spartan 3A
// Tool versions: 
// Description: Converts vector data (exposed points) into raster video
//
// Dependencies: 
//
//////////////////////////////////////////////////////////////////////////////////

module vector2scanline(
		       input clk,          // clock

		       input strobe,       // new exposed pixel trigger
		       input [9:0] x,      // column of exposed pixel
		       input [9:0] y,      // row of exposed pixel

		       // Video output interface
		       input [9:0] xout,   // current pixel column
		       input [9:0] yout,   // current pixel row
		       input newline,      // line buffer swap signal
		       input newframe,     // new frame signal
		       output [7:0] pixel  // output pixel intensity
		       );

   // TODO: figure out how to apply parameters to the port sizes above
   parameter X_WIDTH = 10;     // bit width of column coordinate
   parameter Y_WIDTH = 10;     // bit width of row coordinate
   parameter HIST_WIDTH = 10;  // log2 of maximum lit pixels (exposure buffer)
   parameter AGE_WIDTH = 8;    // width of exposure age counter

   // positions and age of lit pixels
   reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] exposures [(2**HIST_WIDTH)-1:0];
   // output register of exposed pixels buffer
   reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] expr;
   // data for next pixel to store in exposure buffer
   wire [X_WIDTH-1:0] 		       expx;
   wire [Y_WIDTH-1:0] 		       expy;
   wire [7:0] 			       expi;
   // whether this pixel needs to be stored back in exposure buffer
   wire 			       exposed;
   // addresses for exposure buffer read and write ports
   reg [HIST_WIDTH-1:0] 	       exprptr=0, expwptr=0;

   // scanline pixel buffers, store intensity
   // double-buffered; one gets wiped as it is displayed
   // the other gets filled in with current exposures
   reg [AGE_WIDTH-1:0] 		       scanline0 [(2**X_WIDTH)-1:0];
   reg [AGE_WIDTH-1:0] 		       scanline1 [(2**X_WIDTH)-1:0];
   // output intensity for current pixel
   reg [AGE_WIDTH-1:0] 		       pixelout;
   // selection register for which scanline buffer is output/filled in
   reg 				       bufsel = 0;
   // address lines for scanline buffers
   wire [X_WIDTH-1:0] 		       sl0w, sl1w;

   // RAM read out of exposure buffer
   always @(posedge clk) begin
      expr<=exposures[exprptr];
      if (!strobe) begin
	 // do not skip current read position if strobe inserts a new pixel
	 exprptr<=exprptr+1;
      end
   end

   // decode and mux: split fields from exposure buffer, or collect new at strobe
   assign expx = strobe?x:expr[X_WIDTH+Y_WIDTH+AGE_WIDTH-1:Y_WIDTH+AGE_WIDTH];
   assign expy = strobe?y:expr[Y_WIDTH+AGE_WIDTH-1:AGE_WIDTH];
   assign expi = strobe?(2**AGE_WIDTH)-1:expr[AGE_WIDTH-1:0];
   // detect whether pixel even needs to be stored back
   assign exposed = expi!=0;
   
   always @(posedge clk) begin
      // Feed incoming exposures into exposure buffer
      if (exposed) begin
	 exposures[expwptr] <= {expx, expy, expy==yout?expi-1:expi};
	 expwptr <= expwptr+1;
      end
   end

   // scanline buffers switch output or expose roles based on bufsel
   assign sl0w=bufsel?expx:xout;
   assign sl1w=bufsel?xout:expx;
   always @(posedge clk) begin
      // Read out front buffer
      pixelout <= bufsel?scanline1[sl1w]:scanline0[sl0w];
      // TODO: use a next line input port, this incrementer won't work for
      // line 0 (which is unused in display.vhd) and could be shared.
      if (expy==(y+1)) begin
	 // Store exposures for current scanline and wipe front buffer
	 scanline0[sl0w] <= bufsel?expi:0;
	 scanline1[sl1w] <= bufsel?0:expi;
      end
      // swap buffers when signaled
      if (newline) begin
	 bufsel <= ~bufsel;
      end
   end

   // output pixel intensity
   assign pixel = pixelout;
   
endmodule
