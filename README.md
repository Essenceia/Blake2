# Blake2b RTL implementation

Partial implementation of the Blake2 cryptographic hash function (RFC7693) in 
synthesizable RTL.

This code was written in a configurable manner to support both BLAKE2
b and s variants, but **only the b variant has been thougrougly tested thus far**.

This implementation does not currently support secret keys.

## RTL

### blake2 hash  

As blake2 module was written in a paramettric fashion to be configured for both the 64B (b) and 32B (s) versions
of blake2 we implement a wrapper used to pass on the correct configuration.

- `blake2b_hash512` configures for the 64B blake2b version

- `blake2s_hash256` configured for the 32B blake2s version

Blake2b module interface :
```
module blake2b_hash512(
	input clk,
	input nreset,
	input          valid_i,
	input [1023:0] data_i,
	output         hash_v_o,
	output [511:0] hash_o // Seed, output of the hast512
	);
```

Blake2s module interface :
```
module blake2s_hash256(
	input          clk,
	input 	       nreset,

	input 	       valid_i,
	input  [511:0] data_i,
	output         hash_v_o,
	output [255:0] hash_o
	);
```

### blake2

Most of blake2 hash logic is in the `compression` module, this is just another wrapper to set constants. 

Module interface and parameters :
```
module blake2 #( 
	 parameter NN     = 64, // output hash size in bytes, hash-512 : 64, hash-256 : 32 
	 parameter NN_b   = 8'b0100_0000, // hash size in binary, hash-512 : 8'b0100_0000, hash-256 : 8'b0010_0000
	 parameter NN_b_l = 8, // NN_b bit length 
	 parameter W      = 64,// bits in word
	 parameter DD     = 1, // dd, number of message blocks
     parameter LL_b   = { {(W*2)-8{1'b0}}, 8'b10000000},// input size in bytes
	 parameter R1	  = 32, // rotation bits, used in G
	 parameter R2	  = 24,
	 parameter R3	  = 16,
	 parameter R4	  = 63,
	 parameter R 	  = 4'd12 // number of rounds in v srambling
	)(
	input                 clk,
	input                 nreset,

	input 	              valid_i,
	input [(W*16*DD)-1:0] data_i,
	output                hash_v_o,
	output [(NN*8)-1:0]   hash_o // Seed, output of the hash512
	);
```

### compression

This is the main module for the blake2 hash.


Module interface :
```
module compression #(
	parameter W    = 64, 
	parameter LL_b = { {(W*2)-8{1'b0}}, 8'b10000000},
	parameter F_b  = 1'b1, // final block flag
	parameter R1   = 32, // rotation bits, used in G
	parameter R2   = 24,
	parameter R3   = 16,
	parameter R4   = 63,
	parameter R    = 4'd12 // 4'b1100 number of rounds in v srambling
	)
	(
	input               clk,
	input               nreset,
	
	input               valid_i,	
	input [(W*8) -1:0]  h_i, // input driver must guaranty that the value of h_i is constant until a valid output is produced
	input [(W*16)-1:0]  m_i,
	
	output              valid_o,
	output [(W*8) -1:0] h_o
	);
```

## Test bench

Out test bench includes 2 parts :

`blake2_test.vhd`, written in VHDL.
Test's the correctness of this blake2's RTL implementation as well as 
checking no unexpected `X`'s are produced by our module.

`test_vector`, written in C
Uses the official blake2 software implementation as our golden model to
generate test vectors and writes them into files.
        

RTL's output correcteness is checked against multiple test vectors read from files.
If, for a given input the output doesn't match an assert will be fired with a
severity of `failure` and the simulation will be stopped.
Pre-generated vectors are shipped with this repository and can be found in the
`test_vector` folder.
To generate a new random set of test vectors, the code is also contained in the
same folder.

Test vector files :

`*_data_i.txt` : data to be hashed

`*_hash_o.txt` : expected result

### Generate new test vector

External dependancies : libb2's `blake2b.o`

To generate a new test vector, build the C code and run :

```
make clean
make
./blake2
```

(optional) to build with debug :
```
make debug=1
```

The test vector will be directly written to the output files.

### Modify test vectors

The produced test vectors can be modified via macro's in `main.c` :

`TEST_NUM` number of test vectors produced, default is 10

`IN_SIZE` hash input size in bytes, default is 128

`OUT_SIZE` hash output size in bytes, default is 64


