`timescale 1ns / 1ps
// Parametric implementation of Blake2 to implement b and s versions.
// Note : Doesn't support the use of a secret key.
module blake2 #( 
// Configurations for b and s versions :
//
//                            | BLAKE2b          | BLAKE2s          |
//              --------------+------------------+------------------+
//               Bits in word | w = 64           | w = 32           |
//               Rounds in F  | r = 12           | r = 10           |
//               Block bytes  | bb = 128         | bb = 64          |
//               Hash bytes   | 1 <= nn <= 64    | 1 <= nn <= 32    |
//               Key bytes    | 0 <= kk <= 64    | 0 <= kk <= 32    |
//               Input bytes  | 0 <= ll < 2**128 | 0 <= ll < 2**64  |
//              --------------+------------------+------------------+
//               G Rotation   | (R1, R2, R3, R4) | (R1, R2, R3, R4) |
//                constants = | (32, 24, 16, 63) | (16, 12,  8,  7) |
//              --------------+------------------+------------------+
// Configured by default with BLAKE2b
	 parameter NN     = 64, // output hash size in bytes, hash-512 : 64, hash-256 : 32 
	 parameter NN_b   = 8'b0100_0000, // hash size in bytes, hash-512 : 8'b0100_0000, hash-256 : 8'b0010_0000
	 parameter NN_b_l = 8, 
	 parameter W      = 64,
	 parameter DD     = 1, // dd, number of message blocks
         parameter LL_b   = { {(W*2)-8{1'b0}}, 8'b10000000},// input size in bytes
	 parameter R1	  = 32, // rotation bits, used in G
	 parameter R2	  = 24,
	 parameter R3	  = 16,
	 parameter R4	  = 63,
	 parameter R 	  = 4'd12 // number of rounds in v srambling

	)(
	input clk,
	input nreset,
	input 	              valid_i,
	input [(W*16*DD)-1:0] data_i,
	output                hash_v_o,
	output [(NN*8)-1:0]   hash_o // Seed, output of the hash512
	);
	wire [(W*8)-1:0] h;
	wire [W-1:0] IV[0:7];
			 
	assign IV[0] = 64'h6A09E667F3BCC908;
	assign IV[1] = 64'hBB67AE8584CAA73B;
	assign IV[2] = 64'h3C6EF372FE94F82B;
	assign IV[3] = 64'hA54FF53A5F1D36F1;
	assign IV[4] = 64'h510E527FADE682D1;
	assign IV[5] = 64'h9B05688C2B3E6C1F;
	assign IV[6] = 64'h1F83D9ABFB41BD6B;
	assign IV[7] = 64'h5BE0CD19137E2179;
	
	genvar h_idx;
	generate
	       	// h[1..7] := IV[1..7] // Initialization Vector.
	        for(h_idx=1; h_idx<8; h_idx=h_idx+1) begin : loop_h_idx
	       	assign h[(h_idx*W)+W-1:h_idx*W] = IV[h_idx];
	       end
	endgenerate
	// Parameter block p[0]
	// h[0] := h[0] ^ 0x01010000 ^ (kk << 8) ^ nn
	assign h[W-1:0] = IV[0] ^ {{W-32{1'b0}},32'h01010000} ^ {{W-NN_b_l{1'b0}} , NN_b};
	
	compression #(W,LL_b,1'b1, R1,R2,R3,R4, R) blake2_compression(
		.clk(clk),
		.nreset(nreset),
		.valid_i(valid_i),
		.h_i(h), 
		.m_i(data_i),
		.h_o(hash_o),    
		.valid_o(hash_v_o)
	);
//   FUNCTION BLAKE2( d[0..dd-1], ll, kk, nn )
//	  |
//	  |     h[0..7] := IV[0..7]          // Initialization Vector.
//	  |
//	  |     // Parameter block p[0]
//	  |     h[0] := h[0] ^ 0x01010000 ^ (kk << 8) ^ nn
//	  |
//	  |     // Process padded key and data blocks
//	  |     IF dd > 1 THEN
//	  |     |       FOR i = 0 TO dd - 2 DO
//	  |     |       |       h := F( h, d[i], (i + 1) * bb, FALSE )
//	  |     |       END FOR.
//	  |     END IF.
//	  |
//	  |     // Final block.
//	  |     IF kk = 0 THEN
//	  |     |       h := F( h, d[dd - 1], ll, TRUE )
//	  |     ELSE
//	  |     |       h := F( h, d[dd - 1], ll + bb, TRUE )
//	  |     END IF.
//	  |
//	  |     RETURN first "nn" bytes from little-endian word array h[].
//	  |
//	  END FUNCTION.


endmodule
