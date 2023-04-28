// Self test Modules for BLAKE2b and BLAKE2s -- and a stub main().

#include <stdio.h>
#include "file.h"
#include "rand.h"

// number of test vectors to be generated
#define TEST_NUM 10
// input vector size in bytes
#define IN_SIZE  128
// output vector size in bytes
#define OUT_SIZE 64

int main(){
	int i, t;
	tvf_s* tv;
	uint8_t res = 0;
	uint8_t d[IN_SIZE], o[OUT_SIZE];
	
	//res = blake2b_selftest();
	// open files
	tv = setup_files();
	// setup random number generator
	setup_rand();
	
	for(t=0; t<TEST_NUM;t++){
		// generate new test vector
		# ifdef DEBUG
		// manually set test vecot
		for(i=0; i<IN_SIZE;i++){
			d[i] = 0;
		}	
		#else	
		gen_rand(&d,IN_SIZE);
		#endif
		# ifdef DEBUG
		printf("\"inlen\":%d,\"in[%d:0]\":\"", IN_SIZE, IN_SIZE*8-1);
		for(i=IN_SIZE;i>=0;i--){
			printf("%02X",d[i]);
		}
		# endif
		// write input data to file	
		write_data8(tv->f[0], d, IN_SIZE);
		
		// uint8_t *out, const void *in, const void *key, size_t outlen, size_t inlen, size_t keylen );	
		blake2b(&o, &d, NULL, OUT_SIZE, IN_SIZE, 0 );		
		
		// write output to file
		write_data8(tv->f[1], o, OUT_SIZE);

		#ifdef DEBUG
		printf("\",\"outlen\":%d,\"out[%d:0]\":\"", OUT_SIZE, OUT_SIZE*8-1);
		for( i =OUT_SIZE; i>=0 ;i-- ){
			printf("%02X",o[i]);
		};
		printf("\"\n");
		#endif
	
	}	
	// close files
	res |= close_files(tv);
	return res;
}
