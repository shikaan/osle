OSle
---

OSle is a tiny OS that can be run on x86 hardware.

## tl;dr

* Tiny real-mode OS in 16 bits x86 assembly;
* It's written as a bootloader. It's only 510 bytes in total;
* It has a shell, a file system, and process management;
* It runs userland software (check out [`/bin`](./bin/));
* It's a toy. Don't use it for anything serious, please.

## Dependencies

* [GNU make](https://www.gnu.org/software/make/)
* [nasm](https://www.nasm.us)
* [bochs](https://bochs.sourceforge.io)

### MacOS

Using Homebrew

```sh
brew install nasm
brew install bochs
```

### Linux 

Using your local package manager, for example in Debian

```sh
apt install nasm bochs
```

Please refer to the respective packages pages should you experience any problem.

## Run locally

```sh
make start
```

## Build locally

```sh
make boot.o
```

## Use it on a real device

For example using `dd`

```sh
sudo dd if=boot.o of=/dev/YOUR_DEVICE bs=512 count=1
```

## Build userland software

Generate the binary

```sh
make bin/snake.bin
```

and load it in memory with

```sh
loadmem "bin/snake.bin" 0x1000:0x0000
loadmem "bin/another.bin" 0x1000:0x0400  # every file block is 1024 bytes
```
