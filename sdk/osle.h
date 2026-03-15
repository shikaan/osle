#ifndef OSLE_H
#define OSLE_H

// ==== INTERRUPTS ====
// Software interrupt numbers for OSle services.
#define INT_RETURN 0x20
#define INT_FS_FIND 0x21
#define INT_FS_CREATE 0x22
#define INT_FS_WRITE 0x23

// ==== PROCESS MANAGEMENT ====
// Memory address where null-terminated CLI arguments are stored.
#define PM_ARGS 0xFFBF

// ==== FILE SYSTEM ====
//
// Each file on disk is stored as a fixed-size block:
//
//   [0..20]      path   (null-terminated string)
//   [21]         flags  (bit 7: executable)
//   [22..23]     size   (little-endian word)
//   [24..9215]   data
//

// Maximum number of files on disk.
#define FS_FILES 40
// Offset of the file path in the file block.
#define FS_PATH_OFFSET 0
// Maximum length of a file path, in bytes.
#define FS_PATH_SIZE 21
// Offset of the flags field in the file block.
#define FS_FLAGS_OFFSET FS_PATH_SIZE
// Size of the flags field, in bytes.
#define FS_FLAGS_SIZE 1
// Offset of the file size field in the file block.
#define FS_SIZE_OFFSET FS_PATH_SIZE + FS_FLAGS_SIZE
// Size of the file size field, in bytes.
#define FS_SIZE_SIZE 2
// Total size of the file header (path + flags + size).
#define FS_HEADER_SIZE FS_PATH_SIZE + FS_FLAGS_SIZE + FS_SIZE_SIZE
// Offset where file data begins (right after the header).
#define FS_DATA_OFFSET FS_HEADER_SIZE
// Maximum length of file data, in bytes.
#define FS_DATA_SIZE 9192
// Total size of a file block on disk (header + data).
#define FS_BLOCK_SIZE FS_DATA_SIZE + FS_HEADER_SIZE
// It gives the length of an array.
#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

// 8-bit unsigned integer.
typedef unsigned char byte_t;
// 16-bit unsigned integer.
typedef unsigned short word_t;
// File handle returned by open() and create(), used for write().
typedef byte_t handle_t;

// In-memory representation of a file block.
typedef struct {
  byte_t name[FS_PATH_SIZE];
  byte_t flags;
  word_t size;
  byte_t data[FS_DATA_SIZE];
} file_t;

// Returns control to OSle. Use it to exit a running program.
//
// Usage:
//
//   exit();
__attribute__((naked, noreturn)) static void exit(void) {
  __asm__ volatile("int %0" ::"N"(INT_RETURN));
}

// Prints a character on the screen at the current cursor position.
//
// Usage:
//
//   putc('A');
static void putc(char c) {
  __asm__ volatile("mov %0, %%al\n"
                   "mov $0x0E, %%ah\n"
                   "int $0x10\n"
                   :
                   : "r"(c)
                   : "cc", "ax");
}

// Prints up to maxlen characters of a null-terminated string on the screen at
// the current cursor position.
//
// Usage:
//
//   putsn("Hello, world!", 13);
static void putsn(const char *str, unsigned maxlen) {
  __asm__ volatile("mov $0x0E, %%ah\n"
                   ".loop:\n"
                   "  lodsb\n"
                   "  test %%al, %%al\n"
                   "  je .done\n"
                   "  int $0x10\n"
                   "  loop .loop\n"
                   ".done:"
                   : "+S"(str), "+c"(maxlen)
                   :
                   : "ax", "cc");
}

// Prints a null-terminated string on the screen. Shorthand for putsn(str,
// 0xFFFF).
static inline void puts(const char *str) { putsn(str, 0xFFFF); }

// Like putsn, but appends a new line at the end.
//
// Usage:
//
//   putln("Hello, world!", 13);
static void putln(const char *str, unsigned maxlen) {
  putsn(str, maxlen);
  putc('\n');
  putc('\r');
}

// Like puts, but appends a new line at the end. Shorthand for putln(str,
// 0xFFFF).
static inline void putl(const char *str) { putln(str, 0xFFFF); }

// Locates a file on disk and loads it into the provided buffer.
//
// If the file is found, its content is loaded into file and the handle needed
// for write operations is stored in handle.
// Returns non-zero if the file cannot be found.
//
// The file buffer includes the entire file block, headers included. See the
// FILE SYSTEM section above for the layout.
//
// Usage:
//
//   file_t file;
//   handle_t handle;
//   if (open("myfile", &handle, &file)) {
//     // handle error
//   }
static int open(const char *path, handle_t *handle, file_t *file) {
  byte_t error;
  word_t ax;
  __asm__ volatile("int %2\n"
                   "setc %0\n"
                   : "=q"(error), "=a"(ax)
                   : "N"(INT_FS_FIND), "b"(file), "D"(path)
                   : "cc", "memory");
  (*handle) = (byte_t)ax;
  return error;
}

// Creates a new file on disk and loads it into the provided buffer.
//
// If successful, the file is created on disk and its content is loaded into
// file. The handle needed for write operations is stored in handle.
// Returns non-zero if the file cannot be created.
//
// Usage:
//
//   file_t file;
//   handle_t handle;
//   if (create("newfile", &handle, &file)) {
//     // handle error
//   }
static int create(const char *path, handle_t *handle, file_t *file) {
  byte_t error;
  word_t ax;
  __asm__ volatile("int %2\n"
                   "setc %0\n"
                   : "=q"(error), "=a"(ax)
                   : "N"(INT_FS_CREATE), "b"(file), "D"(path)
                   : "cc", "memory");
  (*handle) = (byte_t)ax;
  return error;
}

// Writes the file buffer to disk at the location identified by handle.
//
// Returns non-zero on failure.
//
// Usage:
//
//   file_t file;
//   handle_t handle;
//   // ... open or create the file ...
//   if (write(handle, &file)) {
//     // handle error
//   }
static int write(handle_t handle, file_t *file) {
  byte_t error;
  __asm__ volatile("int %1\n"
                   "setc %0\n"
                   : "=q"(error)
                   : "N"(INT_FS_WRITE), "b"(file), "d"(handle)
                   : "cc", "memory");
  return error;
}

// Reads a character from keyboard input. Blocks until a key is pressed.
//
// Usage:
//
//   char c = getc();
static char getc(void) {
  word_t ax;
  __asm__ volatile("mov $0x00, %%ah\n"
                   "int $0x16"
                   : "=a"(ax)::);
  return (char)(ax & 0xFF);
}

// Pauses execution for a number of microseconds.
//
// Usage:
//
//   sleep(16666);
static void sleep(word_t us) {
  __asm__ volatile("mov $0x86, %%ah\n\t"
                   "int $0x15"
                   :
                   : "c"((word_t)(us >> 16)), "d"((word_t)(us & 0xFFFF))
                   : "ax");
}

// Clear screen and returns to text mode.
//
// Usage:
//
//   cls();
static void cls(void) {
  __asm__ volatile("mov $0x0003, %%ax\n"
                   "int $0x10"
                   :
                   :
                   :);
}

// Returns the number of clock ticks since midnight.
//
// Usage:
//   word_t now = ticks();
static word_t ticks(void) {
  word_t cx, dx;
  __asm__ volatile("xor %%ah, %%ah\n\t"
                   "int $0x1A"
                   : "=c"(cx), "=d"(dx)
                   :
                   : "ax");
  return dx ^ cx;
}

#endif
