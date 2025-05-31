<p align="center">
  <img width="256" src="./docs/logo.svg" alt="logo">
</p>

<p align="center">
A tiny and mighty boot sector OS.
</p>

<div align="center">
  <video src="https://github.com/user-attachments/assets/a2cab8f8-fd60-4947-b886-4b1741072e22"></video>
</div>

<h4 align="center">
  <a href="https://shikaan.github.io/osle/">🚀 Try it out in the browser! 🚀</a>
</h4>


## 👀 Overview

OSle is a [real-mode](https://wiki.osdev.org/Real_Mode) OS that fits in a boot 
sector. 

It's written in x86 assembly and, despite its tiny size (only 510 bytes), it 
packs essential features like:

- **Shell**: Run commands and builtins.
- **File System**: Read, write, and find files on the system.
- **Process Management**: Cooperatively spawn child processes.
- **Userland Software**: Comes with [pre-built software](./bin/) and an 
[SDK](./sdk/) to write your own.

[Check out the online demo](https://shikaan.github.io/osle) to see it in action!

## 📚 Creating your first OSle program

OSle includes a tiny [Software Development Kit (SDK)](./sdk/) that includes
definitions and a toolchain to create your own OSle programs.

Follow the [step-by-step tutorial](./tutorial/) to write your first program!

## 🛠️ Development

To develop OSle and OSle programs you will need the following tools:

- [nasm](https://www.nasm.us)
- [GNU make](https://www.gnu.org/software/make/) (usually preinstalled)
- [bochs](https://bochs.sourceforge.io) (optional)

<details>
<summary>Installation instructions</summary>

#### macOS

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
all the pre-built programs. Using `start` will also run bochs right away.

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
> The following action can damage your hardware. We take no responsibility for
> any damage OSle might cause.

```sh
# generate an OSle image at osle.img
make osle

# write it on a device
sudo dd if=osle.img of=/dev/YOUR_DEVICE bs=512 count=1
```
## 🛠️ `gcc` Installation Tamil to Compile C Language

If you are going to write C programs for Osle, you will need a Cross-Compiler that can compile C.

We recommend using [`i686-elf-gcc`](https://wiki.osdev.org/GCC_Cross-Compiler) as your cross-compiler. On Intel/AMD (x86) systems the default `gcc` will work, but on ARM systems you **must** use a cross-compiler.

### Apple Silicon (macOS)

Install the cross-compiler using Homebrew:

```sh
brew tap nativeosdev/formulae
brew install i686-elf-gcc
```

### ARM Linux (Debian, Raspberry Pi, etc.)

Install the cross-compiler using your package manager or build it manually. For Debian-based systems:

```sh
sudo apt install gcc-i686-linux-gnu
```

Or, follow the [OSDev wiki instructions](https://wiki.osdev.org/GCC_Cross-Compiler) to build `i686-elf-gcc` from source.

### Adapting the Build Scripts

The build scripts can be adapted to use the correct compiler depending on your platform. For example, you can set an environment variable or modify the script to use `i686-elf-gcc` if available, falling back to `gcc` otherwise.

If you need help with this setup, feel free to reach out or open an issue — I'm happy to assist!

---

## 🤝 Contributing

Feel free to explore the [issues](https://github.com/shikaan/osle/issues) and 
[pull requests](https://github.com/shikaan/osle/pulls) to contribute or request
features.

## License

[MIT](./LICENSE)
