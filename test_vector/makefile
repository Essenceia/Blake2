blake2 : main.o blake2b.o blake2s.o
	cc -o blake2 main.o blake2b.o blake2s.o

main.o : main.c
	cc -c main.c
blake2b.o : blake2b.c blake2b.h
	cc -c blake2b.c
blake2s.o : blake2s.c blake2s.h
	cc -c blake2s.c
clean :
	rm blake2 main.o blake2b.o blake2s.o
