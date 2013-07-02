CC      = gcc
CFLAGS  = -Wall -g -D_POSIX_SOURCE -D_BSD_SOURCE -std=c99 -Werror -pedantic

.SUFFIXES: .c .o

.PHONY: all clean

all: dcd_gen chess_core_draft


dcd_gen: dcd_gen.o
chess_core_draft: chess_core_draft.o


clean:
	rm -f $(wildcard *.o)
	rm -f chess_core_draft
	rm -f dcd_gen
