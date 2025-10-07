`timescale 1ns / 1ps
	 
// G Rotation | (R1, R2, R3, R4)
// constants  | (32, 24, 16, 63) 


// Main blake2 module
// default parameter configuration is for blake2b
module blake2 #(	
	parameter NN_b   = 8'b0100_0000, // hash size in binary, hash-512 : 8'b0100_0000, hash-256 : 8'b0010_0000
	parameter NN_b_l = 8, // NN_b bit length
	parameter W      = 64, 
	parameter BB     = W*2,
	parameter LL_b   = { {(W*2)-8{1'b0}}, 8'b10000000},
	parameter F_b    = 1'b1, // final block flag
	parameter R1     = 32, // rotation bits, used in G
	parameter R2     = 24,
	parameter R3     = 16,
	parameter R4     = 63,
	parameter R      = 4'd12 // 4'b1100 number of rounds in v srambling
	)
	(
	input               clk,
	input               nreset,

	input [7:0]         kk_i,
	input [7:0]         nn_i,
	input [63:0]        ll_i,

	input wire          block_first_i,               
	input wire          block_last_i,               
	
	input               valid_i,	
	input [(W*16)-1:0]  d_i,
	
	output              valid_o,
	output [(W*8) -1:0] h_o
	);
	localparam BB_clog2 = $clog2(BB); 
	 
	reg  [2:0] g_idx_q; // G function idx, sub-round
	reg  [3:0] round_q;
	wire [3:0] round_next;
	wire       round_en;
	wire       v_en;
	wire       final_round;

	wire [63:0]  t;	
	reg  [59:0]  block_idx_q;

	wire [W-1:0] v_init[15:0];
	wire [W-1:0] v_init_2[15:0];
	wire [W-1:0] v_next[15:0];
	wire [W-1:0] v_current[15:0];
	reg  [W-1:0] v_q[15:0];
	wire [W-1:0] v_p0[15:0]; // part 0
	wire [W-1:0] v_p1[15:0]; // part 1
	wire [W-1:0] v_p2[15:0]; // part 2
	wire [W-1:0] v_p3[15:0]; // part 3
	wire [1:0]   unused_v_add_carry_p0[15:0]; // part 0
	wire [1:0]   unused_v_add_carry_p1[15:0]; // part 1
	wire [1:0]   unused_v_add_carry_p2[15:0]; // part 2
	wire [1:0]   unused_v_add_carry_p3[15:0]; // part 3
	
	reg  [W-1:0] m_q[15:0]; // stay the same for the entire periode 
	wire [W-1:0] m_current[15:0];
	wire [W-1:0] m_prime[15:0]; // m[s[i]]
		 
	wire [W-1:0] IV[0:7];
	wire [W-1:0] h_init[0:7];
	wire [63:0]  SIGMA[9:0];
	wire [3:0]   sigma_sel;
	wire [63:0]  sigma_row; // currently selected sigma row
	wire [3:0]   sigma_row_elems[15:0]; // currently selected sigma row
	
	assign SIGMA[0] = { 4'd15 , 4'd14, 4'd13, 4'd12, 4'd11, 4'd10, 4'd9,  4'd8,  4'd7,  4'd6,  4'd5,   4'd4,   4'd3,  4'd2,  4'd1,  4'd0 };
	assign SIGMA[1] = { 4'd3  , 4'd5,  4'd7,  4'd11, 4'd2,  4'd0,  4'd12, 4'd1,  4'd6,  4'd13, 4'd15,  4'd9,   4'd8,  4'd4,  4'd10, 4'd14};
	assign SIGMA[2] = { 4'd4  , 4'd9,  4'd1,  4'd7,  4'd6,  4'd3,  4'd14, 4'd10, 4'd13, 4'd15, 4'd2,   4'd5,   4'd0,  4'd12, 4'd8,  4'd11};
	assign SIGMA[3] = { 4'd8  , 4'd15, 4'd0,  4'd4,  4'd10, 4'd5,  4'd6,  4'd2,  4'd14, 4'd11, 4'd12,  4'd13,  4'd1,  4'd3,  4'd9,  4'd7 };
	assign SIGMA[4] = { 4'd13 , 4'd3,  4'd8,  4'd6,  4'd12, 4'd11, 4'd1,  4'd14, 4'd15, 4'd10, 4'd4,   4'd2,   4'd7,  4'd5,  4'd0,  4'd9 };
	assign SIGMA[5] = { 4'd9  , 4'd1,  4'd14, 4'd15, 4'd5,  4'd7,  4'd13, 4'd4,  4'd3,  4'd8,  4'd11,  4'd0,   4'd10, 4'd6,  4'd12, 4'd2 };
	assign SIGMA[6] = { 4'd11 , 4'd8,  4'd2,  4'd9,  4'd3,  4'd6,  4'd7,  4'd0,  4'd10, 4'd4,  4'd13,  4'd14,  4'd15, 4'd1,  4'd5,  4'd12};
	assign SIGMA[7] = { 4'd10 , 4'd2,  4'd6,  4'd8,  4'd4,  4'd15, 4'd0,  4'd5,  4'd9,  4'd3,  4'd1,   4'd12,  4'd14, 4'd7,  4'd11, 4'd13};
	assign SIGMA[8] = { 4'd5  , 4'd10, 4'd4,  4'd1,  4'd7,  4'd13, 4'd2,  4'd12, 4'd8,  4'd0,  4'd3,   4'd11,  4'd9,  4'd14, 4'd15, 4'd6 };
	assign SIGMA[9] = { 4'd0  , 4'd13, 4'd12, 4'd3,  4'd14, 4'd9,  4'd11, 4'd15, 4'd5,  4'd1,  4'd6,   4'd7,   4'd4,  4'd8,  4'd2,  4'd10};
	       		

	generate /* init vector */
		if (W == 64) begin : g_iv_b 
			assign IV[0] = 64'h6A09E667F3BCC908;
			assign IV[1] = 64'hBB67AE8584CAA73B;
			assign IV[2] = 64'h3C6EF372FE94F82B;
			assign IV[3] = 64'hA54FF53A5F1D36F1;
			assign IV[4] = 64'h510E527FADE682D1;
			assign IV[5] = 64'h9B05688C2B3E6C1F;
			assign IV[6] = 64'h1F83D9ABFB41BD6B;
			assign IV[7] = 64'h5BE0CD19137E2179;
		end else begin : g_iv_s
			assign IV[0] = 32'h6A09E667;
			assign IV[1] = 32'hBB67AE85;
			assign IV[2] = 32'h3C6EF372;
			assign IV[3] = 32'hA54FF53A;
			assign IV[4] = 32'h510E527F;
			assign IV[5] = 32'h9B05688C;
			assign IV[6] = 32'h1F83D9AB;
			assign IV[7] = 32'h5BE0CD19;
		end
	endgenerate

	//-------------
	//
	// Init
	//
	// Initialize h init
	genvar h_idx;
	generate
	       	// h[1..7] := IV[1..7] // Initialization Vector.
	        for(h_idx=1; h_idx<8; h_idx=h_idx+1) begin : loop_h_init
	       		assign h_init[h_idx] = IV[h_idx];
	       end
	endgenerate
	// Parameter block p[0]
	// h[0] := h[0] ^ 0x01010000 ^ (kk << 8) ^ nn
	assign h_init[0] = IV[0] ^ {{W-32{1'b0}},32'h01010000} ^ {{W-16{1'b0}},kk_i,{8{1'b0}}} ^ {{W-8{1'b0}} , nn_i};
	

	//----------
	//
	// Function F
	//
	// Calculate t, TODO block index increment
	assign t = block_last_i ? ll_i: (block_idx_q << BB_clog2);
	//
	// Initialize local work vector v[0..15]
	// v[0..7]  := h[0..7]              // First half from state.
	// v[8..15] := IV[0..7]            // Second half from IV.
	genvar v_init_i;
	generate
		for(v_init_i=0;v_init_i<8;v_init_i=v_init_i+1) begin : loop_v_init
			 assign v_init[v_init_i]   = h_init[v_init_i]; // v[0..7] := h[0..7]
			 assign v_init[v_init_i+8] = IV[v_init_i];     // v[8..15] := IV[0..7]
		end
	 endgenerate
	// v[12] := v[12] ^ (t mod 2**w)   // Low word of the offset.
	// v[13] := v[13] ^ (t >> w)       // High word.
	// IF f = TRUE THEN                // last block flag?
	// |   v[14] := v[14] ^ 0xFF..FF   // Invert all bits.
	// END IF.
	assign v_init_2[12] = v_init[12] ^ t[W-1:0]; // Low word of the offset
	assign v_init_2[13] = v_init[13] ^ t[2*W-1:W];// High word of the offset
	assign v_init_2[14] = v_init[14] ^ {W{block_last_i}};
	assign v_init_2[15] = v_init[15];
	genvar v_init_2_i;
	generate
		for(v_init_2_i=0;v_init_2_i<12; v_init_2_i=v_init_2_i+1) begin : loop_v_init_2_i
			assign v_init_2[v_init_2_i] = v_init[v_init_2_i];
		end
	endgenerate


		

    // do 10(s)/12(b) rounds
	genvar v_idx;
	generate
		for(v_idx = 0; v_idx<16; v_idx=v_idx+1 ) begin : loop_v_idx
			assign v_current[v_idx] = ((round_q == 'd0) & (g_idx_q < 'd4))? v_init_2[v_idx] : v_q[v_idx];
		end
	endgenerate

	// write back v_q
	//                                               g_idx_q
	// v := G( v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]] ) 0
	// v := G( v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]] ) 1
	// v := G( v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]] ) 2
	// v := G( v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]] ) 3
	//
	// v := G( v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]] ) 4
	// v := G( v, 1, 6, 11, 12, m[s[10]], m[s[11]] ) 5
	// v := G( v, 2, 7,  8, 13, m[s[12]], m[s[13]] ) 6
	// v := G( v, 3, 4,  9, 14, m[s[14]], m[s[15]] ) 7

	wire [W-1:0] g_a, g_b, g_c, g_d, g_x, g_y;
	always @(*) begin 
		case(g_idx_q[1:0])
			0: g_a = v_current[0];
			1: g_a = v_current[1];
			2: g_a = v_current[2];
			3: g_a = v_current[3];
		endcase
	end

	wire [1:0] g_b_idx;
	assign g_b_idx = g_idx_q[1:0] + g_idx_q[3]; 
	always @(*) begin
		case(g_b_idx)
			0: g_d = v_current[4];
			1: g_d = v_current[5];
			2: g_d = v_current[6];
			3: g_d = v_current[7];
		endcase
	end

	wire [1:0] g_c_idx; 
	assign g_c_idx = g_idx_q + {g_idx_q[3], 1'b0};
	always @(*) begin
		case(g_c_idx)
			0: g_c = v_current[8]; 
			1: g_c = v_current[9]; 
			2: g_c = v_current[10]; 
			3: g_c = v_current[11]; 
 		endcase
	end

	wire [1:0] g_d_idx; 
	assign g_d_idx = g_idx_q + {2{g_idx_q}};
	always @(*) begin
		case(g_d_idx)
			0: g_d = v_current[12];
			1: g_d = v_current[13];
			2: g_d = v_current[14];
			3: g_d = v_current[15];
		endcase
	end

	assign sigma_row  = {64{ round_q == 4'd0 }} & SIGMA[0]
			 		  | {64{ round_q == 4'd1 }} & SIGMA[1]
			 		  | {64{ round_q == 4'd2 }} & SIGMA[2]
			 		  | {64{ round_q == 4'd3 }} & SIGMA[3]
			 		  | {64{ round_q == 4'd4 }} & SIGMA[4]
			 		  | {64{ round_q == 4'd5 }} & SIGMA[5]
			 		  | {64{ round_q == 4'd6 }} & SIGMA[6]
			 		  | {64{ round_q == 4'd7 }} & SIGMA[7]
			 		  | {64{ round_q == 4'd8 }} & SIGMA[8]
			 		  | {64{ round_q == 4'd9 }} & SIGMA[9];
	genvar j;
	generate
		for( j = 0; j < 16; j=j+1 ) begin : loop_sigma_elem
			assign sigma_row_elems[j] = sigma_row[j*4+3:j*4];
		end
	endgenerate

	always @(*) begin
		case(g_idx_q)
			0: {g_x, g_y} <= {sigma_row_elems[0], sigma_row_elems[1]};
			1: {g_x, g_y} <= {sigma_row_elems[2], sigma_row_elems[2]};
			2: {g_x, g_y} <= {sigma_row_elems[4], sigma_row_elems[5]};
			3: {g_x, g_y} <= {sigma_row_elems[6], sigma_row_elems[7]};
			4: {g_x, g_y} <= {sigma_row_elems[8], sigma_row_elems[9]};
			5: {g_x, g_y} <= {sigma_row_elems[10], sigma_row_elems[11]};
			6: {g_x, g_y} <= {sigma_row_elems[12], sigma_row_elems[13]};
			7: {g_x, g_y} <= {sigma_row_elems[14], sigma_row_elems[15]};	
	wire [W-1:0] a,b,c,d; 
	
	G #(.W(W), .R1(R1), .R2(R2), .R3(R3), .R4(R4)) 
	m_g(
		.a_i(g_a),
		.b_i(g_b),
		.c_i(g_c),
		.d_i(g_d),
		.x_i(g_x),
		.y_i(g_y),
		.a_o(a),
		.b_o(b),
		.c_o(c),
		.d_o(d)
	);

	always @(posedge clk) begin
		if ((g_idx_q == 'd0) | (g_idx_q == 'd4))
			v_q[0] <= a;
		if ((g_idx_q == 'd1) | (g_idx_q == 'd5))
			v_q[1] <= a;	
		if ((g_idx_q == 'd2) | (g_idx_q == 'd6))
			v_q[2] <= a;		
		if ((g_idx_q == 'd3) | (g_idx_q == 'd7))
			v_q[3] <= a;
		if ((g_idx_q == 'd0) | (g_idx_q == 'd7))
			v_q[4] <= b;	
		if ((g_idx_q == 'd1) | (g_idx_q == 'd4))
			v_q[5] <= b;	
		if ((g_idx_q == 'd2) | (g_idx_q == 'd5))
			v_q[6] <= b;	
		if ((g_idx_q == 'd3) | (g_idx_q == 'd6))
			v_q[7] <= b;	
		if ((g_idx_q == 'd0) | (g_idx_q == 'd6))
			v_q[8] <= c;	
		if ((g_idx_q == 'd1) | (g_idx_q == 'd7))
			v_q[9] <= c;	
		if ((g_idx_q == 'd2) | (g_idx_q == 'd4))
			v_q[10] <= c;	
		if ((g_idx_q == 'd3) | (g_idx_q == 'd5))
			v_q[11] <= c;			
		if ((g_idx_q == 'd0) | (g_idx_q == 'd5))
			v_q[12] <= d;	
		if ((g_idx_q == 'd1) | (g_idx_q == 'd6))
			v_q[13] <= d;	
		if ((g_idx_q == 'd2) | (g_idx_q == 'd7))
			v_q[14] <= d;	
		if ((g_idx_q == 'd3) | (g_idx_q == 'd4))
			v_q[15] <= d;		
	end


	
	genvar m_q_i;
	generate
		for(m_q_i=0; m_q_i<16; m_q_i=m_q_i+1 ) begin : loop_m_q_i
			// ff
			always @(posedge clk)
			begin
				if (valid_i)
					m_q[m_q_i] <= m_current[m_q_i];
			end
			// m_current ( stand in for next )
			assign m_current[m_q_i] = valid_i ? d_i[(W*m_q_i)+(W-1): W*m_q_i ] : m_q[m_q_i];
		end
	endgenerate
		
	// selecting m prime, re-ordered and indexed into by sigma_row_elems
	// this is the where this get's expensive in hw
	//
	// m_prime[i] = m[s[i]]
	genvar i;
	generate
		for ( i = 0; i < 16; i=i+1 ) begin : loop_m_prime_elem
			assign m_prime[i] = 
						{W{ sigma_row_elems[i] == 4'd0  }} & m_current[0]
					  | {W{ sigma_row_elems[i] == 4'd1  }} & m_current[1]
					  | {W{ sigma_row_elems[i] == 4'd2  }} & m_current[2]
					  | {W{ sigma_row_elems[i] == 4'd3  }} & m_current[3]
					  | {W{ sigma_row_elems[i] == 4'd4  }} & m_current[4]
					  | {W{ sigma_row_elems[i] == 4'd5  }} & m_current[5]
					  | {W{ sigma_row_elems[i] == 4'd6  }} & m_current[6]
					  | {W{ sigma_row_elems[i] == 4'd7  }} & m_current[7]
					  | {W{ sigma_row_elems[i] == 4'd8  }} & m_current[8]
					  | {W{ sigma_row_elems[i] == 4'd9  }} & m_current[9]
					  | {W{ sigma_row_elems[i] == 4'd10 }} & m_current[10]
					  | {W{ sigma_row_elems[i] == 4'd11 }} & m_current[11]
					  | {W{ sigma_row_elems[i] == 4'd12 }} & m_current[12]
					  | {W{ sigma_row_elems[i] == 4'd13 }} & m_current[13]
					  | {W{ sigma_row_elems[i] == 4'd14 }} & m_current[14]
					  | {W{ sigma_row_elems[i] == 4'd15 }} & m_current[15]
					  ;
		end
	endgenerate
//      |   // Cryptographic mixing
//      |   FOR i = 0 TO r - 1 DO           // Ten or twelve rounds.
//      |   |
//      |   |   // Message word selection permutation for this round.
//      |   |   s[0..15] := SIGMA[i mod 10][0..15]
//      |   |
//      |   |   v := G( v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]] )
//      |   |   v := G( v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]] )
//      |   |   v := G( v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]] )
//      |   |   v := G( v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]] )
//      |   |
//      |   |   v := G( v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]] )
//      |   |   v := G( v, 1, 6, 11, 12, m[s[10]], m[s[11]] )
//      |   |   v := G( v, 2, 7,  8, 13, m[s[12]], m[s[13]] )
//      |   |   v := G( v, 3, 4,  9, 14, m[s[14]], m[s[15]] )
//      |   |
//      |   END FOR
// 
//     	FUNCTION G( v[0..15], a, b, c, d, x, y )
//      |
//      |   v[a] := (v[a] + v[b] + x) mod 2**w
//      |   v[d] := (v[d] ^ v[a]) >>> R1
//      |   v[c] := (v[c] + v[d])     mod 2**w
//      |   v[b] := (v[b] ^ v[c]) >>> R2
//      |   v[a] := (v[a] + v[b] + y) mod 2**w
//      |   v[d] := (v[d] ^ v[a]) >>> R3
//      |   v[c] := (v[c] + v[d])     mod 2**w
//      |   v[b] := (v[b] ^ v[c]) >>> R4
//      |
//      |   RETURN v[0..15]
//      |
//      END FUNCTION.

//      |   FOR i = 0 TO 7 DO               // XOR the two halves.
//      |   |   h[i] := h[i] ^ v[i] ^ v[i + 8]
//      |   END FOR.
//      |
//      |   RETURN h[0..7]                  // New state.

	// calculate output h_o value
	generate
		for(h_idx=0; h_idx<8; h_idx=h_idx+1 ) begin : loop_h_o
			assign h_o[(h_idx+1)*W-1:h_idx*W] = h_init[h_idx] ^ v_current[h_idx] ^ v_current[h_idx+8];
		end
	endgenerate
	
	// FSM : count to 12 
	// 0 1 2 3 4 5 6 7 8 9 10 11 12
	// v v v v v v v v v v v  v  h
	//                           fr
	always @(posedge clk)
	begin
		if(~nreset | final_round) begin
			round_q <= 4'b0000;
		end
		else if(round_en) begin
			round_q <= round_next;
		end
	end
	assign round_en   = valid_i | |(round_q); 
	assign round_next = round_q + {3'd0, g_idx_q == 3'd7};
	// output is enabled ( valid )
	assign v_en = round_en & ~final_round;
	assign final_round = ( round_q == R );
	assign valid_o     = final_round;
endmodule
