`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
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
// Revision: $Id$
// $Log$
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module vector2scanline(
		       clk_i,          // clock

		       strobe_i,      // new exposed pixel trigger
		       x_i,          // column of exposed pixel
		       y_i,          // row of exposed pixel

		       // Video output interface
		       xout_i,   // current pixel column
		       yout_i,   // current pixel row
		       newline_i,      // line buffer swap signal
		       newframe_i,     // new frame signal
		       pixel_o  // output pixel intensity
		       /*AUTOARG*/);


   parameter X_WIDTH = 10;     // bit width of column coordinate
   parameter Y_WIDTH = 10;     // bit width of row coordinate
   parameter HIST_WIDTH = 10;  // log2 of maximum lit pixels (exposure buffer)
   parameter AGE_WIDTH = 8;    // width of exposure age counter
   
   input clk_i;
   
   input strobe_i;
   input [X_WIDTH-1:0] x_i;
   input [Y_WIDTH-1:0] y_i;

   input [X_WIDTH-1:0] xout_i;
   input [Y_WIDTH-1:0] yout_i;
   input 	       newline_i, newframe_i;
   output [AGE_WIDTH-1:0] pixel_o;

   // positions and age of lit pixels
   reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] exposures [(2**HIST_WIDTH)-1:0];
   // output register of exposed pixels buffer
   reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] expr;
   // data for next pixel to store in exposure buffer
   wire [X_WIDTH-1:0] 		       expx;
   wire [Y_WIDTH-1:0] 		       expy;
   wire [AGE_WIDTH-1:0] 	       expi;
   // whether this pixel needs to be stored back in exposure buffer
   wire 			       exposed;
   // whether this pixel belongs to the next (backbuffer) scanline
   wire 			       rowmatch;
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
   always @(posedge clk_i) begin
      expr<=exposures[exprptr];
      if (!strobe) begin
	 // do not skip current read position if strobe inserts a new pixel
	 exprptr<=exprptr+1;
      end
   end

   // decode and mux: split fields from exposure buffer, or collect new at strobe
   assign expx = strobe_i?x_i:expr[X_WIDTH+Y_WIDTH+AGE_WIDTH-1:Y_WIDTH+AGE_WIDTH];
   assign expy = strobe_i?y_i:expr[Y_WIDTH+AGE_WIDTH-1:AGE_WIDTH];
   assign expi = strobe_i?(2**AGE_WIDTH)-1:expr[AGE_WIDTH-1:0];
   // detect whether pixel even needs to be stored back
   assign exposed = expi!=0;
   // detect whether pixel applies to current backbuffer
      // TODO: use a next line input port, this incrementer won't work for
      // line 0 (which is unused in display.vhd) and could be shared.
   assign rowmatch=(expy==y_i+1);
   
   always @(posedge clk_i) begin
      // Feed incoming exposures into exposure buffer
      if (exposed) begin
	 exposures[expwptr] <= {expx, expy, expy==yout_i?expi-1:expi};
	 expwptr <= expwptr+1;
      end
   end
   
   // scanline buffers switch output or expose roles based on bufsel
   assign sl0w=bufsel?expx:xout_i;
   assign sl1w=bufsel?xout_i:expx;

   always @(posedge clk_i) begin
      // Read out front buffer
      pixelout <= bufsel?scanline1[xout_i]:scanline0[xout_i];

      // Store exposures for next scanline and wipe front buffer
      if (bufsel) begin
	 if (rowmatch)
	   scanline0[sl0w] <= expi;
	 scanline1[sl1w] <= 0;
      end else begin
	 if (rowmatch)
	   scanline1[sl1w] <= expi;
	 scanline0[sl0w] <= 0;
      end

      // swap buffers when signaled
      if (newline_i) begin
	 bufsel <= ~bufsel;
      end
   end
   
   // output pixel intensity
   assign pixel_o = pixelout;

endmodule
