.POSIX:
CC := clang
CFLAGS :=-std=c23 \
	-O2 \
	-Wall \
	-Wformat \
	-Wformat=all \
	-Wconversion \
	-Werror=format-security \
	-Werror=implicit \
	-Werror=incompatible-pointer-types \
	-Werror=int-conversion \
	-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 \
	-D_GLIBCXX_ASSERTIONS \
	-fstrict-flex-arrays=3 \
	-fstack-clash-protection -fstack-protector-strong \
	-Wl,-z,nodlopen -Wl,-z,noexecstack \
	-Wl,-z,relro -Wl,-z,now \
	-Wl,--as-needed -Wl,--no-copy-dt-needed-entries \
  -fno-delete-null-pointer-checks \
	-fno-strict-overflow \
	-fno-strict-aliasing \
	-ftrivial-auto-var-init=zero \
	-Wextra \
	-fno-common \
	-Winit-self \
	-Wfloat-equal \
	-Wundef \
	-Wshadow \
	-Wpointer-arith \
	-Wcast-align \
	-Wstrict-prototypes \
	-Wstrict-overflow=5 \
	-Wwrite-strings \
	-Waggregate-return \
	-Wcast-qual \
	-Wswitch-default \
	-Wswitch-enum \
	-Wassign-enum \
	-Wimplicit-fallthrough \
	-Wno-ignored-qualifiers \
	-Wno-aggregate-return

DEBUG_FLAGS:=-Werror -g -fdiagnostics-color=always -fsanitize=address,undefined

AS:=nasm
ASFLAGS:=-f bin

.PHONY: start
start: boot.o
	qemu-system-x86_64 -drive file=boot.o,format=raw

# debug: CFLAGS += $(DEBUG_FLAGS)
# debug: all
