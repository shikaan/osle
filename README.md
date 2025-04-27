OSle
---

OSle is a tiny OS that can be run on x86 hardware.

## tl;dr

* tiny real-mode OS in 16 bits x86 assembly;
* written as a bootloader. It's only 510 bytes in total;
* has a shell, a file system, and process management;
* runs [`userland software`](./bin/);
* comes with an [SDK to write your own OSle software](./sdk/);

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