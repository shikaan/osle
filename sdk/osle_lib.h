#ifndef OSLE_SDK_H
#define OSLE_SDK_H

#include "number.h"

// ==== INTERRUPTS ====
//
// INT_RETURN(void) -> void
// Returns control back to OSle. Use it to exit from a running program and give
// control back to the OS.
#define INT_RETURN      0x20

// INT_FS_FIND(di: uint8_t* file_path, bx: uint8_t* dest_buffer) -> (al: file_handle, CF)
// Tries to locate a file whose path is a null-terminated string in di.
// If the file is found, its content will be loaded in the buffer at bx.
// If the file cannot be found, the carry flag is set.
// The file handle needed for write operations is returned in al.
#define INT_FS_FIND     0x21

// INT_FS_CREATE(di: uint8_t* file_path, bx: uint8_t* dest_buffer) -> (al: file_handle, CF)
// Tries to create a file at path di, a null-terminated string.
// If successful, the file will be created on the disk and bx will point to the
// memory area associated with that file. To update the file, use INT_FS_WRITE.
// If the file cannot be created, the carry flag is set.
// The file handle needed for write operations is returned in al.
#define INT_FS_CREATE   0x22

// INT_FS_WRITE(bx: uint8_t* src_buffer, dl: file_handle) -> (CF)
// Writes the file identified by dl to disk, updating its data with the content in bx.
// In case of failure, the carry flag is set.
#define INT_FS_WRITE    0x23

// ==== PROCESS MANAGEMENT ====
//
// OSle will put the arguments passed to your program in a buffer that sits at
// PM_ARGS in the data segment of your program.
#define PM_ARGS         0xFFBF

// ==== FILE SYSTEM ====
//
// Files are stored on the floppy disk where OSle lives.
// Each file on the disk has the following structure:
//   path  uint8_t[21]    - path of the file
//   flags uint8_t        - flags A0000000  (A: executable)
//   size  uint16_t       - file size in bytes
//   data  uint8_t[9192]  - file content

// Maximum number of files you can have on disk
#define FS_FILES            40

// Offset from which to start reading the file path in the file buffer.
#define FS_PATH_OFFSET      0

// Maximum allowed length for a file path.
#define FS_PATH_SIZE        21

// Offset from which to start reading the flags byte in the file buffer.
#define FS_FLAGS_OFFSET     FS_PATH_SIZE

// Size of the flags field.
#define FS_FLAGS_SIZE       1

// Offset from which to start reading the file size in the file buffer.
#define FS_SIZE_OFFSET      (FS_PATH_SIZE + FS_FLAGS_SIZE)

// Length of the word that includes the file size.
#define FS_SIZE_SIZE        2

// Total size of the file header in the file buffer.
#define FS_HEADER_SIZE      (FS_PATH_SIZE + FS_FLAGS_SIZE + FS_SIZE_SIZE)

// Offset from which to start reading the file data in the file buffer.
#define FS_DATA_OFFSET      FS_HEADER_SIZE

// Maximum allowed length for a file block (header + data) on disk.
#define FS_BLOCK_SIZE       9216

void print(const char* str);
void println(const char* str);
void print_hex(u32 num);

u32 string_lenght(const char* str);
void string_copy(char* dest, const char* src);

void return_to_osle(void) {
    asm volatile (
        "int %0\n"
        : 
        : "i"(INT_RETURN)
    );
}

#endif // OSLE_SDK_H