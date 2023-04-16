# Blake2b RTL implementation

Partial implementation of the Blake2 cryptographic hash function (RFC7693) in 
synthesizable RTL.

This code was written in a configurable manner to support both BLAKE2
b and s variants, but **only the b variant has been thougrougly tested thus far**.

This implementation does not currently support secret keys.

## RTL

### blake2 module


### compression module


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

The test vector will be directly written to the output files.

### Modify test vectors

The produced test vectors can be modified via macro's in `main.c` :

`TEST_NUM` number of test vectors produced, default is 10

`IN_SIZE` hash input size in bytes, default is 128

`OUT_SIZE` hash output size in bytes, default is 64


