.POSIX:
AS:=nasm
ASFLAGS:=-f bin

.PHONY: osle
osle: boot.o bin/snake.bin test/fs.bin fixtures/text.txt.bin bin/ed.bin
	dd if=/dev/zero of=osle.img bs=512 count=2880
	dd if=boot.o of=osle.img bs=512 count=1 conv=notrunc
	dd if=bin/snake.bin of=osle.img bs=512 seek=36 conv=notrunc
	dd if=test/fs.bin of=osle.img bs=512 seek=72 conv=notrunc
	dd if=fixtures/text.txt.bin of=osle.img bs=512 seek=108 conv=notrunc
	dd if=bin/ed.bin of=osle.img bs=512 seek=144 conv=notrunc

%.bin: %.s
	$(AS) $(ASFLAGS) -o $*.o $<
	@filename=$(shell basename $@ .bin | cut -c -22) && \
	(	printf "$$filename" | dd bs=22 conv=sync of=header.bin 2>/dev/null && \
		filesize=$$(stat -c %s "$*.o" 2>/dev/null || stat -f %z "$*.o") && \
		perl -e 'print pack("v", '$$filesize');' >> header.bin )
	cat header.bin $*.o > $@
	rm -f header.bin # $*.o

.PHONY: start
start: osle
	bochs -q -f .bochsrc

.PHONY: debug
debug: osle
	bochs -dbg -rc .bochsinit -f .bochsrc

.PHONY: clean
clean:
	rm -rf *.img *.o *.bin **/*.o **/*.bin
