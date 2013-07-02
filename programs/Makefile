.SUFFIXES:
AS=./assemble
KERNEL=kernel.img

%.o: %.s
	$(AS) $< $@
	cp $@ $(KERNEL)

chess: chess.o

clean:
	rm -f $(wildcard *.o)
	rm -f kernel.img

.PHONY: clean
