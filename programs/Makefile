.SUFFIXES:
ARCH := $(shell uname -m | sed -e s/.*86.*/x86/ -e s/arm.*/arm/ -e s/sa110/arm/)
ifeq ($(ARCH), arm)
	AS = ./assemble_arm
else
	AS = ./assemble_x86
endif
KERNEL = kernel.img

%.o: %.s
	$(AS) $< $@
	cp $@ $(KERNEL)

chess: chess.o

clean:
	rm -f $(wildcard *.o)
	rm -f kernel.img

.PHONY: clean
