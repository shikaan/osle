<p align="center">
  <img width="256" src="./docs/logo.svg" alt="logo">
</p>

<p align="center">
A tiny and mighty bootloader OS.
</p>


<h4 align="center">
  <a href="https://shikaan.github.io/OSle/">🚀 Try it out in the browser! 🚀</a>
</h4>


## 👀 Overview

OSle is a [real-mode](https://wiki.osdev.org/Real_Mode) OS that fits in a 
bootloader. 

It's written in x86 assembly and, despite its tiny size (only 510 bytes), it 
packs essential features like:

- **Shell**: Run commands and builtins.
- **File System**: Read, write, and find files on the system.
- **Process Management**: Cooperatively spawn child processes.
- **Userland Software**: Comes with [prebuilt software](./bin/) and an 
[SDK](./sdk/) to write your own.

[Check out the online demo](https://shikaan.github.io/OSle) to see it in action.

## 📚 Creating your fist OSle program

OSle includes a tiny [Software Development Kit (SDK)](./sdk/) that includes
definitions and a toolchain to create your own OSle programs.

Follow the [step-by-step tutorial](./tutorial/) to write your first program!

## 🛠️ Development

To develop OSle or guest programs that run on OSle, you will need the following
tools:

- [nasm](https://www.nasm.us)
- [GNU make](https://www.gnu.org/software/make/) (usually preinstalled)
- [bochs](https://bochs.sourceforge.io) (optional)

<details>
<summary>Installation instructions</summary>

#### MacOS

Install dependencies using Homebrew:

```sh
brew install nasm
brew install bochs
```

#### Linux

Install dependencies using your local package manager, e.g., on Debian:

```sh
apt install nasm bochs
```
</details>

### Build and Run OSle locally

These recipes will compile OSle and use the [SDK](./sdk/) to compile and bundle
all the prebuilt programs. Using `start` will also run bochs right away.

```sh
# build and run osle on bochs
make start

# or

# build osle
make osle
# use QEMU to run it
qemu-system-i386 -fda osle.img
```

### Build and Run your OSle program

```sh
# ensure you have a working OSle image at osle.img
make osle

# compile your source to generate my_file.bin
sdk/build my_file.s

# bundle my_file.bin into the osle.img image
sdk/pack my_file.bin

# run it!
qemu-system-i386 -fda osle.img
```

### Use OSle on a Real Device

Write the built image to a device using `dd`:

> [!WARNING]  
> The following action can damage your hardware. I take no responsibility for
> any damage OSle might cause.

```sh
# generate an OSle image at osle.img
make osle

# write it on a media
sudo dd if=osle.img of=/dev/YOUR_DEVICE bs=512 count=1
```

## 🤝 Contributing

Feel free to explore the [issues](https://github.com/shikaan/OSle/issues) and [pull requests](https://github.com/shikaan/OSle/pulls) to contribute or request features.

## License

[MIT](./LICENSE)