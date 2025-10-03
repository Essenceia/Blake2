`timescale 1ns / 1ps

module right_rot #(
	parameter ROT_I=32,
	parameter W=64
	)
	(
	input  [W-1:0] data_i,
	output [W-1:0] data_o
	);
	assign data_o[W-1:0] = { data_i[ROT_I-1:0], data_i[W-1:ROT_I]};
endmodule

module addder_3way #(
	parameter W=64
	)
	(
	input [W-1:0] x0_i,
	input [W-1:0] x1_i,
	input [W-1:0] x2_i,
	
	output [W-1:0] y_o
	);
	wire         carry;
	wire         unused_carry;
	wire [W-1:0] tmp;
	
	assign { carry , tmp } = x0_i + x1_i;
	assign { unused_carry, y_o } = x2_i + { carry , tmp };
endmodule

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
module G(
	parameter W=32,
	parameter a,
	parameter b,
	parameter c,
	parameter d,
	parameter R1,
	parameter R2,
	parameter R3,
	parameter R4
	)(
	input [W-1:0]  v_i[15:0],
	input [W-1:0]  x_i,
	input [W-1:0]  y_i,

	output [W-1:0] v_o[15:0]
	);
	wire [W-1:0] a0, a1;
	wire [W-1:0] b0, b1;
	wire [W-1:0] c0, c1;
	wire [W-1:0] d0, d1;
	wire unusued_carry0, unusued_carry0;

	// v[a] := (v[a] + v[b] + y) mod 2**w
	addder_3way #(.W(W)) m_add_0(
		.x0_i(v_i[a]),
		.x1_i(v_i[b]),
		.x2_i(x_i),
		.y_o(a0)
	);
	// v[d] := (v[d] ^ v[a]) >>> R1
	right_rot #(R1 , W) m_rot_0
	(
		.data_i((v_i[d] ^ a0[a])),
		.data_o(d0)
	);
	// v[c] := (v[c] + v[d])     mod 2**w
	{unused_carry, c0} = v_i[c] + d0;
	
	// v[b] := (v[b] ^ v[c]) >>> R2
	right_rot #(R2 , W) m_rot_1
	(
		.data_i((v_i[b] ^ c0)),
		.data_o(b0)
	);
	// v[a] := (v[a] + v[b] + y) mod 2**w
	adder_3way #(.W(W)) m_add_1
	(
		.x0_i(a0),
		.x1_i(b0),
		.x2_i(y),
		.y_o(a1)
	);
	// v[d] := (v[d] ^ v[a]) >>> R3
	right_rot #(R3 , W) m_rot_2
	(
		.data_i((d0 ^ a0)),
		.data_o(d1)
	);

	// v[c] := (v[c] + v[d])     mod 2**w
	{unused_carry1, c1} = c0 + d1;

	// v[b] := (v[b] ^ v[c]) >>> R4
	right_rot #(R4 , W) m_rot_3
	(
		.data_i((b0 ^ c1)),
		.data_o(b1)
	);

	generate(i=0; i<15; i++) begin: loop_v
		if ((i != a) && (i != b) && (i != c) && (i!= d)) begin
			assign v_o[i] = v_i[i];
		end
	endgenerate

	assign v_o[a] = a1;
	assign v_o[b] = b1;
	assign v_o[c] = c1;
	assign v_o[d] = d1;
	
endmodule 
