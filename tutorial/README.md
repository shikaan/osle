# Tutorial

A step-by-step tutorial to write your first OSle program.

Each tutorial is a self-contained, commented source file that you can compile and
run on your OSle image. The tutorials are meant to be read in order:

1. **Hello World** — Print a message on screen. A gentle introduction to the SDK.
2. **Arguments** — Read user input. Build an `echo` program.
3. **Files** — Work with the file system. Build an `rm` program.

## Which language should I pick?

The tutorials are available in both **x86 Assembly** (`.s`) and **C** (`.c`).

Pick **Assembly** if you want to understand how OSle works under the hood: you
will interact directly with BIOS interrupts and OSle's services.

Pick **C** if you'd rather focus on building programs without worrying about
low-level details.

Both languages produce the same kind of binary and have access to the same OS
features.

## Build and Run

Ensure you have the required [dependencies](../README.md) installed, then:

```sh
# ensure you have a working OSle image
make osle

# compile your tutorial (pick one)
sdk/occ tutorial/01-hello.c   # or tutorial/01-hello.s

# bundle it into the image
sdk/pack tutorial/01-hello.bin

# run it
qemu-system-i386 -fda osle.img
```
