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
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module vector2scanline(
    input clk,

    input strobe,
    input [9:0] x,
    input [9:0] y,

    input [9:0] xout,
    input [9:0] yout,
	 input newline,
	 input newframe,
    output [7:0] pixel
    );

parameter X_WIDTH = 10;
parameter Y_WIDTH = 10;
parameter HIST_WIDTH = 10;
parameter AGE_WIDTH = 8;

reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] exposures [(2**HIST_WIDTH)-1:0];
reg [X_WIDTH+Y_WIDTH+AGE_WIDTH-1:0] expr;
wire [X_WIDTH-1:0] expx;
wire [Y_WIDTH-1:0] expy;
wire [7:0] expi;
wire exposed;
reg [HIST_WIDTH-1:0] exprptr=0, expwptr=0;
	
// double-buffered; one gets wiped as it is displayed
// the other gets filled in with current exposures
reg [AGE_WIDTH-1:0] scanline0 [(2**X_WIDTH)-1:0];
reg [AGE_WIDTH-1:0] scanline1 [(2**X_WIDTH)-1:0];
reg [AGE_WIDTH-1:0] pixelout;
reg bufsel = 0;
wire [X_WIDTH-1:0] sl0w, sl1w;

always @(posedge clk) begin
	expr<=exposures[exprptr];
	if (!strobe) begin
		exprptr<=exprptr+1;
	end
end
assign expx = strobe?x:expr[X_WIDTH+Y_WIDTH+AGE_WIDTH-1:Y_WIDTH+AGE_WIDTH];
assign expy = strobe?y:expr[Y_WIDTH+AGE_WIDTH-1:AGE_WIDTH];
assign expi = strobe?(2**AGE_WIDTH)-1:expr[AGE_WIDTH-1:0];
assign exposed = expi!=0;

always @(posedge clk) begin
	// Feed incoming exposures into exposure buffer
	if (exposed) begin
		exposures[expwptr] <= {expx, expy, expy==yout?expi-1:expi};
		expwptr <= expwptr+1;
	end
end

assign sl0w=bufsel?expx:xout;
assign sl1w=bufsel?xout:expx;
always @(posedge clk) begin
	// Read out & wipe front buffer
	// Store exposures for current scanline as well
	if (expy==(y+1)) begin
		scanline0[sl0w] <= bufsel?expi:0;
		scanline1[sl1w] <= bufsel?0:expi;
		pixelout <= bufsel?scanline1[xout]:scanline0[xout];
	end
	if (newframe) begin
		bufsel <= ~bufsel;
	end
end

assign pixel = pixelout;

endmodule
