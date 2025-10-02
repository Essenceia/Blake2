module top(
	input clk, 
	input nreset, 

	input valid_i, 
	input [511:0] data_i, 
	output hash_v_o,
	output [255:0] hash_o
); 

	blake2s_hash256 m_blake2(
		.clk(clk),
		.nreset(nreset),

		.valid_i(valid_i),
		.data_i(data_i),

		.hash_v_o(hash_v_o),
		.hash_o(hash_o)
	);
endmodule

