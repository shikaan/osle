; Calling convention
;   - caller needs to preserve all registers, never the callee;
;   - ax is the return register;
%macro debugger 0
  xchg bx,bx
%endmacro

[org 0x7c00]
bits 16

register_interrupts:
  xor ax, ax
  mov ds, ax
  mov bx, boot
  mov [PM_RETURN * 4], bx     ; register boot at interrupt PM_RETURN
  mov [PM_RETURN * 4 + 2], ax

boot:
  xor ax, ax
  mov ds, ax      ; Data segment
  mov es, ax      ; Extra segment
  mov ss, ax      ; Stack segment
  mov sp, 0x7c00  ; Set stack pointer

  mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
  int 0x10

main:
  call shell
  jmp $          ; Infinite loop

; Definitions
; ===========

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
  jne .print_char                 ; else, try to print

.print_char:
  cmp byte [INPUT.len], INPUT_CAP
  jae .wait_for_key               ; nop if the input buffer is full

  xor bh, bh                       ; clear high byte for good measure
  mov bl, [INPUT.len]
  mov di, [INPUT.ptr]
  mov byte [di + bx], al          ; append char at the end of the buffer
  mov byte [di + bx + 1], 0       ; null terminate the input
  inc byte [INPUT.len]            ; inclease size

  call scr_tty                    ; write the new character on screen

  jmp .wait_for_key

.backspace:
  cmp byte [INPUT.len], 0
  je .wait_for_key                ; nop if input is empty

  call scr_tty                    ; print backspace (move backwards)

  mov ax, 0x0A00                  ; 0A: write character, 00: null-byte
  xor bh, bh                      ; page = 0
  mov cx, 1                       ; how many repetitions?
  int 0x10                        ; put null-byte on screen (i.e., delete)

  mov bx, [INPUT.len]
  mov di, [INPUT.ptr]
  mov byte [di + bx], 0x0         ; remove last char from input
  dec byte [INPUT.len]            ; decrease input buffer size

  jmp .wait_for_key

.cmd:
  cmp byte [INPUT.len], 0
  je .flush                       ; reprint prompt if input is empty

  call sh_cr

  mov cx, 3                       ; all commands below have length 3

  mov di, [INPUT.ptr]
  mov si, CLEAR
  repe cmpsb
  je .cmd_clear                   ; command is the builtin clear

  mov di, [INPUT.ptr]
  mov si, WF
  repe cmpsb
  je .cmd_wf                      ; command is the builtin write file

  mov di, [INPUT.ptr]
  mov si, RF
  repe cmpsb
  je .cmd_rf                      ; command is the builtin read file

  call .cmd_run                   ; command is the builtin run
  jc .cmd_error                   ; command is unknown

.cmd_clear:
  mov ax, 0x0600                  ; scroll up and clear window
  xor cx, cx                      ; top left corner = 0,0
  mov dx, 0x184F                  ; bottom right corner = 18,4F
  mov bh, 0x07                    ; set background color
  int 0x10                        ; clear screen

  mov dx, -1                      ; move at the top of the screen
  mov ax, 0x0200
  xor bh, bh
  int 0x10
  jmp .flush

.cmd_wf:
  mov di, [INPUT.ptr]
  add di, 3                       ; skip "wf ", di now points to args
  mov si, di                      ; load args in si for parsing

.find_space:
  lodsb
  cmp al, ' '
  jnz .find_space
                                  ; now di is first arg and si second
  push si                         ; we store si and null-separate args in INPUT
  mov byte [si-1], 0

  call fs_create                  ; create filw with name in di
  jc .done

  mov di, ax
  pop si
  mov cx, [INPUT.len]
  add cx, [INPUT.ptr]
  sub cx, si                      ; cx = length of third argument
  call fs_write                   ; write bytes to the file we created earlier

.done:
  jmp .flush

.cmd_rf:
  mov di, [INPUT.ptr]
  add di, 3                           ; put filename in di
  call fs_find
  jc .cmd_error
  mov bx, ax                          ; store file pointer in bx
  mov dx, FS_SEGMENT                  ; update ds to read file correctly
  mov ds, dx
  lea si, [es:bx + FS_HEADER_SIZE]    ; store data pointer in si
  mov cx, word [es:bx + FS_NAME_SIZE] ; store file size in cx
  call str_print
  xor ax, ax
  mov ds, ax                          ; restore ds to zero
  jmp .flush

.cmd_run:
  mov di, [INPUT.ptr]
  call pm_exec
  ret

.cmd_error:
  mov si, ERROR
  mov cx, 5
  call str_print

.flush:
  call sh_cr
  mov di, [INPUT.ptr]
  mov word [di], 0
  mov byte [INPUT.len], 0
  mov es, [di]                        ; reset es to zero
  jmp .print_prompt

.break:
  ret

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

; str_copy(si: u8* string, di: u8* string, cx: count) -> void
; Copies up to cx bytes from source into destination.
str_copy:
  lodsb
  stosb
  test al, al
  je .done
  loop str_copy
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
; Files are only stored in memory. They live at segment FS_SEGMENT and to
; simplify addressing we will only allow 64 files of 1kb each. Each block
; representing a file will have the following structure
;
; File Entry (1024 bytes)
;   name  u8[22]    - name of the file
;   size  u16       - file size in bytes
;   data  u8[1000]  - file content
FS_SEGMENT      equ 0x1000
FS_FILES        equ 64
FS_NAME_SIZE    equ 22
FS_HEADER_SIZE  equ 24
FS_BLOCK_SIZE   equ 1024

; fs_switch_segment(void)
; Switches es to the file segment, to perform file operations.
fs_switch_segment:
  mov ax, FS_SEGMENT
  mov es, ax
  ret

; fs_create(di: u8* name) -> (ax: relative_address)
; Creates an empty file with a given name. Returns the address of the file
; relative to the FS_SEGMENT. If the file exists, it truncates it.
; Sets carry flag in case of failure.
fs_create:
  call fs_switch_segment
  mov cx, FS_FILES
  xor bx, bx
.find_empty_block:
  cmp byte [es:bx], 0                 ; a block is free if file name is empty
  je .found
  add bx, FS_BLOCK_SIZE               ; advance to nex block
  loop .find_empty_block
  stc                                 ; signal failure
  ret
.found:
  mov word [es:bx + FS_NAME_SIZE], 0  ; set file size
  mov si, di
  mov di, bx
  mov cx, FS_NAME_SIZE
  push bx
  call str_copy                       ; set name in the block
  pop ax                              ; return offset of the found block
  clc
  ret

; fs_write(di: u16 address, si: u8* buffer, cx: size)
; Writes cx bytes of the si buffer in the file at di with data_offset bx.
fs_write:
  call fs_switch_segment
  mov word [es:di + FS_NAME_SIZE], cx     ; set new size
  lea di, byte [es:di + FS_HEADER_SIZE]   ; point to data
.copy:
  lodsb
  stosb
  loop .copy
.done:
  ret

; fs_find(di: u8* name) -> (ax: relative_address)
; Look for a file with a given name. Sets carry flag in case of failure.
fs_find:
  call fs_switch_segment
  mov dx, di              ; store the name in dx
  xor bx, bx
  mov cx, FS_FILES        ; loop through all the files to find ours
.loop:
  mov di, bx
  mov si, dx
.compare_names:
  cmpsb
  jne .break              ; filenames differ, break
  cmp byte [si-1], 0
  je .match               ; end of the file, found a metch
  jmp .compare_names
.break:
  add bx, FS_BLOCK_SIZE   ; advance to next block
  loop .loop
  stc                     ; signal error
  ret
.match:
  mov ax, bx              ; ax = file address
  clc                     ; success
  ret

; Process Management
; ==================
; The model for this OS is cooperative: the program that is started takes on
; the machine. It will return control to the main os by means of PM_RETURN
; interrupt.
PM_RETURN   equ 0x20
PM_SEGMENT  equ 0x2000

; pm_exec(di: u8* filename)
; Loads a binary in the PM_SEGMENT and executes it.
pm_exec:
  call fs_find
  jc .done
  mov bx, ax
  mov ax, FS_SEGMENT
  mov ds, ax
  lea si, [es:bx + FS_HEADER_SIZE]
  mov ax, PM_SEGMENT
  mov es, ax
  xor di, di
  mov cx, word [ds:bx + FS_NAME_SIZE]
  repe movsb
  jmp PM_SEGMENT:0
.done:
  ret

; Data
; ====
; Uppercase values are constants.

CLEAR     db 'cl', 0
WF        db 'wf '                ; Space is required for correct matching
RF        db 'rf '                ;   when command takes arguments
ERROR     db 'error'

INPUT:
  .ptr:     dw 0x7E00
  .len:     db 0
INPUT_CAP   equ 0x80

; Pad the file to reach 510 byte and add boot signature at the end.
times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
