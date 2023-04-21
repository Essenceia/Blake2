
ifndef debug
#debug :=
endif

FLAGS = -Wall -Wextra -Wconversion -Wshadow -Wundef -fno-common  -Wno-unused-parameter -Wno-type-limits
CC = cc $(if $(debug),-DDEBUG -g)
LD = cc
LIB = libb2_la-blake2b.o

blake2 : main.o file.o rand.o
	$(LD) -o blake2 -g main.o file.o rand.o $(LIB)

main.o : main.c
	$(CC) -c main.c $(LIB) $(FLAGS)
file.o : file.c file.h
	$(CC) -c file.c $(FLAGS)
rand.o : file.c
	$(CC) -c rand.c $(FLAGS)

clean :
	rm -f blake2 main.o file.o rand.o
	rm -f vgcore.* *.txt
