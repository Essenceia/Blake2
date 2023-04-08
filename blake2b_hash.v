`timescale 1ns / 1ps
// Blake2b wrapper for 512 and 256 hash
module blake2b_hash512(
	input clk,
	input nreset,
	input 			valid_i,
	input [1023:0] data_i,
	output         hash_v_o,
	output [511:0] hash_o // Seed, output of the hast512
	);
	blake2 #( .NN(64), .NN_b(8'b0100_0000)) m_hash512(
		.clk(clk),
		.nreset(nreset),
		.valid_i(valid_i),
		.data_i(data_i),
		.hash_v_o(hash_v_o),
      .hash_o(hash_o)
	 );
endmodule

module blake2b_hash256(
	input clk,
	input nreset,
	input 			valid_i,
	input [1023:0]  data_i,
	output         hash_v_o,
	output [255:0] hash_o
	);
	blake2 #( .NN(32), .NN_b(8'b0010_0000)) m_hash256(
		.clk(clk),
		.nreset(nreset),
		.valid_i(valid_i),
		.data_i(data_i),
		.hash_v_o(hash_v_o),
      .hash_o(hash_o)
	 );
endmodule
