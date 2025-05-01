%include "sdk/osle.inc"
%include "sdk/bochs.inc"

; Calling convention
;   - caller needs to preserve all registers, never the callee;
;   - ax is the return register;

[org 0x7c00]
bits 16

boot:
  xor ax, ax
  mov ds, ax      ; Data segment
  mov es, ax      ; Extra segment
  mov ss, ax      ; Stack segment
  mov sp, 0x7c00  ; Set stack pointer

  mov byte [input_len], 0

register_interrupts:
  xor di, di                        ; start with interrupt 0x20 (INT_RETURN)
  mov cx, INTERRUPT_COUNT
  mov si, INTERRUPTS

.loop:
  lodsw                             ; load word from INTERRUPTS into ax
  mov [INT_RETURN * 4 + di], ax     ; set offset for interrupt vector
  mov [INT_RETURN * 4 + di + 2], ds ; set segment for interrupt vector
  add di, 4                         ; move to next vector (4 bytes each)
  loop .loop

reset_screen:
  mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
  int 0x10

main:

; Shell
; -----

; shell(void)
; Launches an interactive command prompt, the entry point of our real-mode OS.
shell:
.print_prompt:
  mov al, '>'
  call scr_tty

.wait_for_key:
  xor ax, ax                      ; Function 0: Read Character
  int 0x16

  cmp al, 0x0D                    ; key is ENTER
  je .cmd
  cmp al, 0x08                    ; key is BACKSPACE
  je .backspace

.print_char:
  cmp byte [input_len], INPUT_CAP
  jae .wait_for_key               ; nop if the input buffer is full

  movzx bx, byte [input_len]      ; load input length into bx
  mov di, INPUT_PTR
  mov [di + bx], al               ; append char at the end of the buffer
  inc byte [input_len]            ; increase size
  mov byte [di + bx + 1], 0       ; null terminate the input

  call scr_tty                    ; write the new character on screen

  jmp .wait_for_key

.backspace:
  cmp byte [input_len], 0
  je .wait_for_key                ; nop if input is empty

  call scr_tty                    ; print backspace (move backwards)

  mov ax, 0x0A00                  ; 0A: write character, 00: null-byte
  xor bh, bh                      ; page = 0
  mov cx, 1                       ; how many repetitions?
  int 0x10                        ; put null-byte on screen (i.e., delete)

  mov bx, [input_len]
  mov byte [INPUT_PTR + bx], 0x0  ; remove last char from input
  dec byte [input_len]            ; decrease input buffer size

  jmp .wait_for_key

.cmd:
  call sh_cr

  mov si, CLEAR
  call .cmp_cmd
  je .cmd_clear                   ; command is the builtin clear

  mov si, LS
  call .cmp_cmd
  je .cmd_ls                      ; command is the builtin ls

  call .cmd_run                   ; command is the builtin run
  jc .cmd_error                   ; command is unknown

.cmp_cmd:
  mov cx, 3
  mov di, INPUT_PTR
  repe cmpsb
  ret

.cmd_clear:
  jmp boot

.cmd_ls:
  call fs_list
  jmp .flush

.cmd_run:
  mov al, ' '
  mov cx, FS_PATH_SIZE
  mov di, INPUT_PTR
  repne scasb
  mov byte [di - 1], 0

  mov si, di
  mov di, INPUT_PTR
  call pm_exec
  jc .cmd_error                     ; only returns in case of errors

.cmd_error:
  mov si, ERROR
  mov cx, ERROR_LEN
  call str_print

.flush:
  call sh_cr
  mov byte [input_len], 0
  jmp .print_prompt

; sh_cr(void)
; Moves the cursor at the beginning of the next line.
sh_cr:
  mov al, 0x0d
  call scr_tty
  mov al, 0x0a
  call scr_tty
  ret

; String
; ------

; str_print(si: u8* string, cx: count) -> void
; Prints a string up to cx chars
str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
.loop:
  lodsb
  test al, al    ; is end of the string?
  je .done
  int 0x10
  loop .loop
.done:
  ret

; Screen
; ------

; scr_tty(al: u8 char) -> void
; Like put_char, but advances the cursor as well.
scr_tty:
  mov ah, 0x0E  ; 0E: teletype
  xor bh, bh    ; page = 0
  int 0x10
  ret

; File System
; ===========

; int_failure(void)
; Returns failure from an interrupt, setting the carry flag.
; You cannot use stc here because in an interrupt handler, flags are saved.
int_failure:
  mov bx, sp
  or word [bx + 4], 1
  iret

; int_success(void)
; Returns success from an interrupt, clear the carry flag.
; You cannot use clc here because in an interrupt handler, flags are saved.
int_success:
  mov si, sp
  and word [si + 4], 0xFFFE
  iret

; int_fs_find(di: u8* name, bx: u8* dest) -> (al: file_index)
; Look for a file with a given name. Sets carry flag in case of failure.
FS_FILE_MEMORY equ 0x7E80
int_fs_find:
  cmp byte [di], 0
  je int_failure                  ; bail if path is empty

  mov cx, FS_FILES
  mov dl, 1
.search_matching_block:
  pusha
    call fs_read
    jc int_failure

    mov cx, FS_PATH_SIZE
    lea si, [bx + FS_PATH_OFFSET] ; put name in source register for comparison
.compare_names:
    lodsb
    cmp al, byte [di]
    jne .break
    test al, al                   ; stop comparison if null char is encountered
    je .found
    inc di
    loop .compare_names
    je .found
.break:
  popa
  inc dl
  loop .search_matching_block
  jmp int_failure
.found:
  popa
  mov al, dl                        ; move file index in the return register
  jmp int_success

; int_fs_create(di: u8* path, bx: u8* destination) -> (al: file_index)
; Creates a new file and allocate memory for it in bx. Returns the file index
; in the range (0-40)
int_fs_create:
  cmp byte [di], 0
  je int_failure           ; bail if path is empty

  mov cx, FS_FILES
  mov dl, 1
.search_empty_block:
  pusha
    call fs_read
    jc int_failure

    cmp byte [bx], 0        ; a file with an empty name is considered empty
    je .found
  popa
  inc dl
  loop .search_empty_block
  jmp int_failure
.found:
  popa
  push dx
    mov si, di
    mov di, bx
    mov cx, FS_PATH_SIZE
.copy_path:
    lodsb
    stosb
    test al, al
    je .done_copying
    loop .copy_path
.done_copying:
    call fs_write
  pop ax
  jc int_failure

  jmp int_success

; int_fs_write(bx: u8* file_buffer, dl: file_index)
; Writes the input buffer to the file whose index is dl.
int_fs_write:
  call fs_write      ; save buffer on disk
  jc int_failure
  jmp int_success

; fs_disk(ah: u8 operation, bx: u8* destination, dl: u8 file_index)
; Performs a disk operation whose source/destination is bx on track dh.
;   ah = 0x02 is read
;   ah = 0x03 is write
; This function encapsulates all assumptions on file system of OSle
;   - One file per track
;   - All ops are on the whole track
;   - Only one side of drive A
fs_read:
  mov ax, 0x0212  ; al = 12 means 18 sectors
  jmp fs_disk
fs_write:
  mov ax, 0x0312  ; al = 12 means 18 sectors
fs_disk:
  mov ch, dl      ; track number (i.e., the file index)
  mov cl, 1       ; start from sector 1
  xor dx, dx      ; dh = 0 (drive A), dl = head 0
  int 0x13
  ret

; fs_list()
; Prints on screen a list of files in the current directory
fs_list:
  mov cx, FS_FILES
  mov dl, 1
.loop:
  pusha
    mov bx, FS_FILE_MEMORY
    call fs_read

    cmp byte [bx], 0
    je .continue
    mov cx, FS_PATH_SIZE
    lea si, [bx + FS_PATH_OFFSET] ; put name in source register for comparison
    call str_print
    call sh_cr
.continue:
  popa
  inc dl
  loop .loop
.done:
  ret

; Process Management
; ==================
; The model for this OS is cooperative: the program that is started takes on
; the machine. It will return control to the main os by means of INT_RETURN
; interrupt.
PM_SEGMENT    equ 0x2000
PM_STACK      equ 0XFFBE

pm_switch_to_guest_segment:
  mov ax, PM_SEGMENT
  mov es, ax
  ret

; pm_exec(di: u8* filename, si: u8* args)
; Loads a binary in the PM_SEGMENT and runs it. Sets carry flag upon failure.
pm_exec:
  mov bx, FS_FILE_MEMORY
  pusha
    int INT_FS_FIND
    jc .done
    cmp byte [bx + FS_FLAGS_OFFSET], 0x80         ; bail if not executable
    jb .done  
  popa

  call pm_switch_to_guest_segment

  xor ax, ax                                      ; zero guest sector for good
  mov cx, 0xFFFF                                  ;   measure
  mov di, PM_SEGMENT
  repe stosb

  mov cx, INPUT_PTR
  add cx, [input_len]
  cmp si, cx                                      ; if si > input_len, means no
  jae .copy_executable                            ; argument needs to be passed

  mov di, PM_ARGS
  mov cx, INPUT_CAP
  repe movsb                                      ; copy args in args section

.copy_executable:
  lea si, [bx + FS_DATA_OFFSET]                   ; put file data in source
  xor di, di                                      ; select PM_SEGMENT as dest
  mov cx, word [bx + FS_SIZE_OFFSET]              ; only copy `size` bytes
  repe movsb

  call pm_switch_to_guest_segment
  mov ds, ax                                      ; guest DS = PM_SEGMENT
  mov ss, ax                                      ; guest SS = PM_SEGMENT
  mov sp, PM_STACK                                ; guest SP = Top of segment

  jmp PM_SEGMENT:0
.done:
  popa
  ret

; Data
; ====
; Uppercase values are constants.

CLEAR     db 'cl', 0
LS        db 'ls', 0
ERROR     db 'ERR'
ERROR_LEN equ $-ERROR

input_len   db  0
INPUT_PTR   equ 0x7E00
INPUT_CAP   equ 64

INTERRUPT_COUNT equ 4
INTERRUPTS:
  dw boot
  dw int_fs_find
  dw int_fs_create
  dw int_fs_write

; Pad the file to reach 510 byte and add boot signature at the end.
times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
