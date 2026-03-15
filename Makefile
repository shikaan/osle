.POSIX:
AS:=nasm
ASFLAGS:=-f bin

%.bin: %.s
	sdk/occ -o $@ $<

%.bin: %.c
	sdk/occ -o $@ $<

.PHONY: osle_test
osle_test: osle fixtures/text.txt.bin test/fs.test.bin
	sdk/pack test/fs.test.bin
	sdk/pack fixtures/text.txt.bin

.PHONY: osle
osle: osle.o \
	bin/ed.bin bin/more.bin bin/rm.bin bin/mv.bin bin/help.bin \
	bin/touch.bin bin/tetris.bin bin/echo.bin
	dd if=/dev/zero of=osle.img bs=512 count=2880
	dd if=osle.o of=osle.img bs=512 count=1 conv=notrunc
	sdk/pack bin/ed.bin
	sdk/pack bin/more.bin
	sdk/pack bin/rm.bin
	sdk/pack bin/mv.bin
	sdk/pack bin/help.bin
	sdk/pack bin/touch.bin
	sdk/pack bin/tetris.bin
	sdk/pack bin/echo.bin

.PHONY: run
run:
	bochs -q -f .bochsrc

.PHONY: start
start: osle run

.PHONY: debug
debug: osle_test
	bochs -dbg -rc .bochsinit -f .bochsrc

.PHONY: clean
clean:
	rm -rf *.img *.o *.bin **/*.o **/*.bin
