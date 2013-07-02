DCD=../../src/dcd_gen

PIECES=king queen bishop knight rook pawn game_over
all:
	$(foreach var,$(PIECES),$(DCD) ascii/$(var)_as.txt out/$(var).out;)

clean:
	rm out/*.out

.PHONY: all clean
