; Calling convention
;   - caller needs to preserve all registers, never the callee;
;   - ax is the return register;
%macro debugger 0
  xchg bx,bx
%endmacro

[org 0x7c00]
bits 16

boot:
  xor ax, ax
  mov ds, ax      ; Data segment
  mov es, ax      ; Extra segment
  mov ss, ax      ; Stack segment
  mov sp, 0x7c00  ; Set stack pointer

  mov byte [INPUT.len], 0

register_interrupts:
  xor di, di                        ; Start with interrupt 0x20 (INT_RETURN)
  mov cx, INTERRUPT_COUNT
  mov si, INTERRUPTS

.loop:
  lodsw                             ; Load word from INTERRUPTS into ax
  mov [INT_RETURN * 4 + di], ax     ; Set offset for interrupt vector
  mov [INT_RETURN * 4 + di + 2], ds ; Set segment for interrupt vector
  add di, 4                         ; Move to next interrupt vector (4 bytes each)
  loop .loop

reset_screen:
  mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
  int 0x10

main:
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
  push es

.wait_for_key:
  xor ax, ax                      ; Function 0: Read Character
  int 0x16

  cmp al, 0x0D                    ; key is ENTER
  je .cmd
  cmp al, 0x08                    ; key is BACKSPACE
  je .backspace

.print_char:
  cmp byte [INPUT.len], INPUT_CAP
  jae .wait_for_key               ; nop if the input buffer is full

  movzx bx, byte [INPUT.len]      ; load input length into bx
  mov di, [INPUT.ptr]
  mov [di + bx], al               ; append char at the end of the buffer
  inc byte [INPUT.len]            ; increase size
  mov byte [di + bx + 1], 0       ; null terminate the input

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

.cmd_rf:
  mov di, [INPUT.ptr]
  add di, 3                           ; put filename in di
  mov bx, FS_FILE_MEMORY
  int INT_FS_FIND
  jc .cmd_error

  lea si, [bx + FS_HEADER_SIZE]
  mov cx, word [bx + FS_NAME_SIZE]
  call str_print
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
  mov byte [INPUT.len], 0
  pop es
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
; Files are stored on the floppy disk itself. To simplify lookups, we allocate
; one file per track and use only one side. This means every file can be 9kb
; (18 sectors * 512 bytes) and we can have 40 files in total.
;
; File Entry (9216 bytes)
;   name  u8[22]    - name of the file
;   size  u16       - file size in bytes
;   data  u8[9192]  - file content
FS_FILES        equ 40
FS_NAME_SIZE    equ 22
FS_HEADER_SIZE  equ 24
FS_BLOCK_SIZE   equ 9216

int_failure:
  mov bx, sp
  or word [bx+4], 1
  iret

int_success:
  mov si, sp
  and word [si+4], 0xFFFE
  iret

; int_fs_find(di: u8* name, bx: u8* dest) -> (al: track_number)
; Look for a file with a given name. Sets carry flag in case of failure.
FS_FILE_MEMORY equ 0x7E80
int_fs_find:
  mov cx, FS_FILES
  mov dl, 1
.search_loop:
  push cx
  push dx
  push di
    mov ax, 0x0212          ; ah = read; al = 1 sector (name is in first sector)
    mov ch, dl              ; track number
    mov cl, 1               ; start from sector 1
    xor dx, dx              ; dh = 0 (drive A), dl = head 0
    int 0x13
    jc int_failure

    mov cx, FS_NAME_SIZE ; fixme
    mov si, bx
    .compare_names:
      lodsb
      cmp al, byte [di]
      jne .break
      test al, al
      je .found
      inc di
      loop .compare_names
      je .found
  .break:
  pop di
  pop dx
  pop cx

  inc dl
  loop .search_loop
  jmp int_failure
.found:
  pop di
  pop dx
  pop cx
  mov al, dl
  jmp int_success

; Process Management
; ==================
; The model for this OS is cooperative: the program that is started takes on
; the machine. It will return control to the main os by means of INT_RETURN
; interrupt.
PM_SEGMENT  equ 0x2000
PM_STACK    equ 0XFFFE

; pm_exec(di: u8* filename)
; Loads a binary in the PM_SEGMENT and runs it. Sets carry flag upon failure.
pm_exec:
  mov bx, FS_FILE_MEMORY
  int INT_FS_FIND
  jc .done

  lea si, [bx + FS_HEADER_SIZE]    ; prepare source (data segment of file)

  mov ax, PM_SEGMENT
  mov es, ax
  xor di, di                          ; prepare destination (PM_SEGMENT)

  mov cx, word [bx + FS_NAME_SIZE]    ; only copy as many bytes as in the size
  repe movsb                          ; copy!

  mov ax, PM_SEGMENT
  mov ds, ax                ; Guest DS = PM_SEGMENT
  mov es, ax                ; Guest ES = PM_SEGMENT
  mov ss, ax                ; Guest SS = PM_SEGMENT
  mov sp, PM_STACK          ; Guest SP = Top of segment

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

INTERRUPT_COUNT equ 2
INTERRUPTS:
  dw boot
  dw int_fs_find

INT_RETURN    equ 0x20
INT_FS_FIND   equ 0x21

; Pad the file to reach 510 byte and add boot signature at the end.
times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
