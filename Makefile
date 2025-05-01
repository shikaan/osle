.POSIX:
AS:=nasm
ASFLAGS:=-f bin

%.bin: %.s
	sdk/build $<

.PHONY: osle_test
osle_test: osle fixtures/text.txt.bin test/fs.test.bin
	sdk/pack test/fs.test.bin
	sdk/pack fixtures/text.txt.bin

.PHONY: osle
osle: osle.o bin/snake.bin bin/ed.bin bin/more.bin bin/rm.bin bin/mv.bin bin/help.bin
	dd if=/dev/zero of=osle.img bs=512 count=2880
	dd if=osle.o of=osle.img bs=512 count=1 conv=notrunc
	sdk/pack bin/snake.bin
	sdk/pack bin/ed.bin
	sdk/pack bin/more.bin
	sdk/pack bin/rm.bin
	sdk/pack bin/mv.bin
	sdk/pack bin/help.bin

.PHONY: start
start: osle
	bochs -q -f .bochsrc

.PHONY: debug
debug: osle_test
	bochs -dbg -rc .bochsinit -f .bochsrc

.PHONY: clean
clean:
	rm -rf *.img *.o *.bin **/*.o **/*.bin
