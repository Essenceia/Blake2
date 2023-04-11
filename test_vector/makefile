
ifndef debug
#debug :=
endif

CC = cc $(if $(debug),-DDEBUG -g)
LD = cc

blake2 : main.o blake2b.o blake2s.o file.o
	$(LD) -o blake2 -g main.o blake2b.o blake2s.o file.o

main.o : main.c
	$(CC) -c main.c
blake2b.o : blake2b.c blake2b.h
	$(CC) -c blake2b.c
blake2s.o : blake2s.c blake2s.h
	$(CC) -c blake2s.c
file.o : file.c file.h
	$(CC) -c file.c
clean :
	rm -f blake2 main.o blake2b.o blake2s.o file.o
	rm -f vgcore.* *.txt
