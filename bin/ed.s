[org 0x7c00]
bits 16

xor ax, ax
mov ds, ax      ; Data segment
mov es, ax      ; Extra segment
mov ss, ax      ; Stack segment
mov sp, 0x7c00  ; Set stack pointer

reset_screen:
  mov ax, 0x0003
  int 0x10

main:
.wait_for_key:
  call draw_cursor
  xor ax, ax
  int 0x16

.handle_key:
  cmp word [BUFFER.len], BUFFER_CAP
  jae .wait_for_key

  cmp ax, 0x4B00
  je .left
  cmp ax, 0x4D00
  je .right
  cmp ax, 0x4800
  je .up
  cmp ax, 0x5000
  je .down

  cmp al, 0x0D
  je .return
  cmp al, 0x08
  je .backspace

  cmp al, 32          ; Check if >= space (ASCII 32)
  jb .wait_for_key    ; If below 32, it's not printable
  cmp al, 126         ; Check if <= tilde (ASCII 126) 
  ja .wait_for_key    ; If above 126, it's not printable

  call scr_tty
  inc byte [CURSOR]
  jmp .wait_for_key

.left:
  cmp word [CURSOR], 0
  je .wait_for_key
  dec byte [CURSOR]
  jmp .wait_for_key

.right:
  cmp byte [CURSOR], 79
  jae .wait_for_key
  inc byte [CURSOR]
  jmp .wait_for_key

.up:
  cmp word [CURSOR+1], 0
  je .wait_for_key
  dec byte [CURSOR+1]
  jmp .wait_for_key

.down:
  cmp byte [CURSOR+1], 24
  jae .wait_for_key
  inc byte [CURSOR+1]
  jmp .wait_for_key

.return:
  inc byte [CURSOR+1]
  mov byte [CURSOR], 0
  jmp .wait_for_key

.backspace:
  cmp byte [CURSOR], 0
  je .wait_for_key                ; nop if beginning of line

  dec byte [CURSOR]
  call draw_cursor

  mov ax, 0x0A20                  ; 0A: write character, 00: null-byte
  xor bh, bh                      ; page = 0
  mov cx, 1                       ; how many repetitions?
  int 0x10                        ; put null-byte on screen (i.e., delete)

  jmp .wait_for_key

; update_current_line(dx: delta_len, al: char)
; Appends character at the end of the buffer and updates length accordingly
update_current_line:
  mov bx, word [BUFFER.len]
  mov di, [BUFFER.ptr]
  mov byte [di + bx], 0x0
  add word [BUFFER.len], dx
  ret

draw_cursor:
  xor bh, bh        ; Page number = 0
  mov ah, 0x02      ; Set cursor position function
  mov dx, [CURSOR]
  int 0x10
  ret

; scr_tty(al: u8 char) -> void
scr_tty:
  mov ah, 0x0E  ; 0E: teletype
  xor bh, bh    ; page = 0
  int 0x10
  ret

; str_print(si: u8* string, cx: count) -> void
; Prints a string up to cx chars
str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
  xor bh, bh    ; page = 0
.loop:
  lodsb
  test al, al    ; is end of the string?
  je .done
  int 0x10
  loop .loop
.done:
  ret

CURSOR dw 0x0000

BUFFER_CAP equ 512
BUFFER:
  .ptr: dw 0x3000
  .len: dw 0

times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
