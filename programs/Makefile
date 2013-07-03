.SUFFIXES:
ARCH := $(shell uname -m | sed -e s/i.86/i386/ -e s/arm.*/arm/ -e s/sa110/arm/)
ifeq ($(ARCH), i386)
	AS = ./assemble_x86
else
	AS = ./assemble_arm
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
