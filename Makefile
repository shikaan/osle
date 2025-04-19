.POSIX:
AS:=nasm
ASFLAGS:=-f bin

%.bin: %.s
	$(AS) $(ASFLAGS) -o $*.o $<
	@filename=$(shell basename $@ | cut -c -22) && \
	(	printf "$$filename" | dd bs=22 conv=sync of=header.bin 2>/dev/null && \
		printf '\x00\x02' >> header.bin )
	cat header.bin $*.o > $@
	rm -f header.bin $*.o

.PHONY: start
start: boot.o
	bochs -q -f .bochsrc

.PHONY: debug
debug: boot.o bin/ed.bin bin/snake.bin bin/hello.bin
	bochs -dbg -rc load_bin -f .bochsrc
