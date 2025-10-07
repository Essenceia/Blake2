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
	
	input        data_v_i,	
	input [7:0]  data_i,
	
	output              valid_o,
	output [(W*8) -1:0] h_o
	);
	localparam BB_clog2 = $clog2(BB); 
	 
	reg  [2:0] g_idx_q; // G function idx, sub-round
	reg  [3:0] round_q;
	wire [3:0] round_next;
	wire       round_en;
	wire       final_round;

	wire [63:0]  t;	
	reg  [57:0]  block_idx_q;

	wire [W-1:0] v_init[15:0];
	wire [W-1:0] v_init_2[15:0];
	wire [W-1:0] v_current[15:0];
	reg  [W-1:0] v_q[15:0];
	wire [W-1:0] h_next[7:0];
	reg  [W-1:0] h_q[7:0];
	
	reg  [W*16-1:0] m_q;
	wire [W-1:0] m_matrix[15:0];
		 
	wire [W-1:0] IV[0:7];
	wire [W-1:0] f_h[0:7];
	wire [W-1:0] h_init[0:7];
	wire [63:0]  SIGMA[9:0];
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

	// fsm
	reg first_block_q; 
	reg last_block_q; 
	reg fsm_q;
	wire f_finished;
	reg res_cnt_q;

	localparam S_IDLE = 'd0;
	localparam S_WAIT_DATA = 'd1;
	localparam S_F = 'd2;
	localparam S_F_END = 'd3; // write back h, save on mux on path to write back v to h
	localparam S_RES = 'd4;

	always @(posedge clk) begin
		if (~nreset) begin
			first_block_q <= 1'b0;
			last_block_q <= 1'b0;
			fsm_q <= S_IDLE;
		end else begin
			case (fsm_q) 
				S_IDLE: fsm_q <= data_v_i ? S_WAIT_DATA: S_IDLE;
				S_WAIT_DATA: fsm_q <= (data_v_i & (data_idx_i == 6'd63))? S_F : S_WAIT_DATA;
				S_F: fsm_q <= f_finished ? S_F_END : S_F;
				S_F_END: fsm_q <= last_block_q ? S_RES : S_WAIT_DATA;
				S_RES: fsm_q <= res_cnt_q == 'd31 ? S_IDLE: S_RES;
			endcase
		end
	end

	always @(posedge clk) begin
		case (fsm_q)
			S_WAIT_DATA: begin
				first_block_q <= data_v_i ? block_first_i : first_block_q;
				last_block_q <= data_v_i ? block_last_i : last_block_q;
			end
			S_F:
			S_F_END: begin
				first_block_q <= first_block_q;
				last_block_q <= last_block_q;
			end
			default: begin
				first_block_q <= 1'b0;
				last_block_q <= 1'b0;
			end
		endcase
	end

	wire unusued_f_cnt_q;
	always @(posedge clk) begin
		case (fsm_q)
			S_F: {unused_f_cnt_q, round_q, g_idx_q} <= {round_q, g_idx_q} + 'b1;
			default: {round_q, g_idx_q} <= '0;
		endcase
	end
	assign f_finished = {rount_q, g_idx_q} == { R , 3'd7};

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
	assign t = last_block_q ? ll_i: {block_idx_q, {BB_clog2{1'b0}}};
	//
	// Initialize local work vector v[0..15]
	// v[0..7]  := h[0..7]              // First half from state.
	// v[8..15] := IV[0..7]            // Second half from IV.
	genvar i_v_init;
	generate
		for(i_v_init=0;i_v_init<8;i_v_init=i_v_init+1) begin : loop_v_init
			 assign f_h[i_v_init]      = first_block_q ? h_init[i_v_init]: h_q[i_v_init]; // v[0..7] := h[0..7]
			 assign v_init[i_v_init]   = f_h; // v[0..7] := h[0..7]
			 assign v_init[i_v_init+8] = IV[i_v_init];     // v[8..15] := IV[0..7]
		end
	 endgenerate
	// v[12] := v[12] ^ (t mod 2**w)   // Low word of the offset.
	// v[13] := v[13] ^ (t >> w)       // High word.
	// IF f = TRUE THEN                // last block flag?
	// |   v[14] := v[14] ^ 0xFF..FF   // Invert all bits.
	// END IF.
	assign v_init_2[12] = v_init[12] ^ t[W-1:0]; // Low word of the offset
	assign v_init_2[13] = v_init[13] ^ t[2*W-1:W];// High word of the offset
	assign v_init_2[14] = v_init[14] ^ {W{last_block_q}};
	assign v_init_2[15] = v_init[15];
	genvar v_init_2_i;
	generate
		for(v_init_2_i=0;v_init_2_i<12; v_init_2_i=v_init_2_i+1) begin : loop_v_init_2_i
			assign v_init_2[v_init_2_i] = v_init[v_init_2_i];
		end
	endgenerate


		

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

	reg [W-1:0] g_a, g_b, g_c, g_d, g_x, g_y;
	always @(*) begin 
		case(g_idx_q[1:0])
			0: g_a = v_current[0];
			1: g_a = v_current[1];
			2: g_a = v_current[2];
			3: g_a = v_current[3];
		endcase
	end

	wire [1:0] g_b_idx;
	wire unused_g_b_idx;
	assign {unused_g_b_idx, g_b_idx} = g_idx_q[1:0] + {2'b0,g_idx_q[2]}; 
	always @(*) begin
		case(g_b_idx)
			0: g_b = v_current[4];
			1: g_b = v_current[5];
			2: g_b = v_current[6];
			3: g_b = v_current[7];
		endcase
	end

	wire [1:0] g_c_idx; 
	wire unused_g_c_idx; 
	assign {unused_g_c_idx,g_c_idx} = g_idx_q + {g_idx_q[2], 1'b0};
	always @(*) begin
		case(g_c_idx)
			0: g_c = v_current[8]; 
			1: g_c = v_current[9]; 
			2: g_c = v_current[10]; 
			3: g_c = v_current[11]; 
 		endcase
	end

	wire [1:0] g_d_idx; 
	wire unused_g_d_idx; 
	assign {unused_g_d_idx,g_d_idx} = g_idx_q + {1'b0,{2{g_idx_q[2]}}};
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

	reg [3:0] g_x_idx, g_y_idx;
	always @(*) begin
		case(g_idx_q)
			0: {g_x_idx, g_y_idx} = {sigma_row_elems[0], sigma_row_elems[1]};
			1: {g_x_idx, g_y_idx} = {sigma_row_elems[2], sigma_row_elems[2]};
			2: {g_x_idx, g_y_idx} = {sigma_row_elems[4], sigma_row_elems[5]};
			3: {g_x_idx, g_y_idx} = {sigma_row_elems[6], sigma_row_elems[7]};
			4: {g_x_idx, g_y_idx} = {sigma_row_elems[8], sigma_row_elems[9]};
			5: {g_x_idx, g_y_idx} = {sigma_row_elems[10], sigma_row_elems[11]};
			6: {g_x_idx, g_y_idx} = {sigma_row_elems[12], sigma_row_elems[13]};
			7: {g_x_idx, g_y_idx} = {sigma_row_elems[14], sigma_row_elems[15]};
		endcase
	end
	assign g_x = m_matrix[g_x_idx];
	assign g_y = m_matrix[g_y_idx];
	
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
		if (fsm_q == S_F) begin
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
	end



	always @(posedge clk)
	begin
		if(data_v_i)
			m_q <= {data_i, m_q[511:8]};
	end

	genvar m_q_i;
	generate
		for(m_q_i=0; m_q_i<16; m_q_i=m_q_i+1 ) begin : loop_m_q_i
			assign m_matrix[m_q_i] = m_q[m_q_i];
		end
	endgenerate
		
	// FOR i = 0 TO 7 DO               // XOR the two halves.
	// |   h[i] := h[i] ^ v[i] ^ v[i + 8]
	// END FOR.
	generate
		for(h_idx=0; h_idx<8; h_idx=h_idx+1 ) begin : loop_h_o
			assign h_next[(h_idx+1)*W-1:h_idx*W] = f_h[h_idx] ^ v_q[h_idx] ^ v_q[h_idx+8];
		end
	endgenerate

	always @(posedge clk) 
		if (fsm_q == S_F_END) 
			h_q <= h_next;
	
endmodule
