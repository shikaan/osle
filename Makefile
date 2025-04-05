.POSIX:
AS:=nasm
ASFLAGS:=-f bin

.PHONY: start
start: boot.o
	bochs -q -f .bochsrc

.PHONY: debug
debug: boot.o
	bochs -debugger -q -f .bochsrc
