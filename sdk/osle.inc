; This file encapsulates all the development constants needed for guest
; applications. It's safe to be re-included multiple times in the same project.

%ifndef OSLE_SDK
%define OSLE_SDK
; ==== INTERRUPTS ====
;
; Interrupts are exposed only for I/O operations where OSle is opinionated. 
; You are encouraged to use appropriate BIOS interrupts for all other
; standard I/O operations (e.g., clear screen, print chars).   

; INT_RETURN(void) -> void
; Returns control back to OSle. Use it to exit from a running program and give
; control back to the OS.
;
; NOTE
; OSle process management is cooperative: while your app is running, _nothing 
; else_ is. Ensure you return control to the OS at some point; otherwise, the 
; machine will hang.
; 
; Usage:
;     int INT_RETURN
;
INT_RETURN    equ 0x20

; INT_FS_FIND(di: u8* file_path, bx: u8* dest_buffer) -> (al: file_handle, CF)
; Tries to locate a file whose path is a null-terminated string in di.
;
; If the file is found, its content will be loaded in the buffer at bx.
; If the file cannot be found, the carry flag is set.
; The file handle needed for write operations is returned in al.
;
; NOTE
; There is no bound check: ensure [bx] has at least FS_BLOCK_SIZE bytes of
; available memory. See FILE SYSTEM for details.
;
; NOTE
; The bx buffer will include the _entire_ file, headers included. See FILE
; SYSTEM for details. 
;
; Usage:
;   mov bx, 0x4000
;   mov di, FILE_NAME
;   int INT_FS_FIND
;   jc fail
;   jmp success
;
INT_FS_FIND   equ 0x21

; INT_FS_CREATE(di: u8* file_path, bx: u8* dest_buffer) -> (al: file_handle, CF)
; Tries to create a file at path di, a null-terminated string.
;
; If successful, the file will be created on the disk and bx will point to the
; memory area associated with that file. To update the file, use INT_FS_WRITE.
; If the file cannot be created, the carry flag is set.
; The file handle needed for write operations is returned in al.
;
; NOTE
; There is no bound check: ensure [bx] has at least FS_BLOCK_SIZE bytes of
; available memory. See FILE SYSTEM for details.
;
; NOTE
; The bx buffer will include the _entire_ file, headers included. See FILE
; SYSTEM for details. 
;
; Usage:
;   mov bx, 0x4000
;   mov di, FILE_NAME
;   int INT_FS_CREATE
;   jc fail
;   jmp success
;
INT_FS_CREATE equ 0x22

; INT_FS_WRITE(bx: u8* src_buffer, dl: file_handle) -> (al: file_handle, CF)
; Writes the file identified by dl to disk, updating its data with the content 
; in bx.
;
; In case of failure, the carry flag is set.
; The file handle needed for subsequent write operations is returned in al.
;
; Usage:
;   mov bx, 0x4000
;   mov dl, al        ; al = file_handle from previous find or create
;   int INT_FS_WRITE
;   jc fail
;   jmp success
;
INT_FS_WRITE  equ 0x23

; ==== PROCESS MANAGEMENT ====
;
; OSle process management is cooperative. Launching a program means letting the
; program run in real mode with all hardware at its disposal.
;
; You are expected not to update the segment registers: to operate safely, your
; program needs to stay within the sector it gets allocated.

; OSle will put the arguments passed to your program in a buffer that sits at
; PM_ARGS in the data segment of your program.
;
; Usage:
;   mov di, PM_ARGS   ; di points to the null-terminated string of arguments
PM_ARGS     equ 0xFFBF

; ==== FILE SYSTEM ====
;
; Files are stored on the floppy disk where OSle lives. To simplify lookups in 
; our constrained space, OSle allocates one file per track and only uses one
; side. Consequently, every file can only occupy up to 9KB in size 
; (18 sectors * 512 bytes) and there will only be 40 files in total.
; File operations return a file handle, which is the index (1-39) of the file on
; the disk.
;
; Each file on the disk has the following structure:
;
; File Entry (9216 bytes)
;   path  u8[22]    - path of the file
;   size  u16       - file size in bytes
;   data  u8[9192]  - file content
;

; FS_FILES
; Maximum number of files you can have on disk
FS_FILES        equ 40

; FS_PATH_OFFSET
; Offset from which to start reading the file path in the file buffer. 
; The path is a null-terminated string with max length of FS_PATH_SIZE.
;
; Usage:
;   mov si, [FILE_BUFFER + FS_PATH_OFFSET] ; si includes the file path
;
FS_PATH_OFFSET  equ 0

; FS_PATH_SIZE
; Maximum allowed length for a file path.
;
FS_PATH_SIZE    equ 22

; FS_SIZE_OFFSET
; Offset from which to start reading the file size in the file buffer. 
; The size is a 16-bit word representing the file size in bytes.
;
; Usage:
;   mov cx, word [FILE_BUFFER + FS_SIZE_OFFSET] ; cx is the file size
;
FS_SIZE_OFFSET  equ FS_PATH_SIZE

; FS_SIZE_SIZE
; Length of the word that includes the file size.
;
FS_SIZE_SIZE    equ 2

; FS_HEADER_SIZE
; Total size of the file header in the file buffer.
; The file data starts just after the header
FS_HEADER_SIZE  equ FS_PATH_SIZE + FS_SIZE_SIZE

; FS_DATA_OFFSET
; Offset from which to start reading the file data in the file buffer. 
; 
; Usage:
;   mov bx, [FILE_BUFFER + FS_DATA_OFFSET] ; bx points to the file data 
FS_DATA_OFFSET  equ FS_HEADER_SIZE

; FS_BLOCK_SIZE
; Maximum allowed length for a file block (header + data) on disk.
;
FS_BLOCK_SIZE   equ 9216

%endif
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s