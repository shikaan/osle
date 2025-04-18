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

  cmp byte [CURSOR], MAX_COLS-1
  jae .wait_for_key

  cmp al, 32                      ; only try to print printable chars
  jb .wait_for_key
  cmp al, 126 
  ja .wait_for_key

  call write_char
  mov cx, [CURSOR+1]              ; redraw current line with the new char
  call draw_line
  inc byte [CURSOR]               ; update logical cursor accordingly
  jmp .wait_for_key

.left:
  cmp word [CURSOR], 0
  je .wait_for_key
  dec byte [CURSOR]
  jmp .wait_for_key

.right:
  cmp byte [CURSOR], MAX_COLS-1
  jae .wait_for_key

  movzx bx, byte [CURSOR+1]
  mov cl, byte [lines_len + bx]
  cmp byte [CURSOR], cl
  jae .wait_for_key

  inc byte [CURSOR]
  jmp .wait_for_key

.up:
  cmp word [CURSOR+1], 0
  je .wait_for_key
  dec byte [CURSOR+1]

  movzx bx, byte [CURSOR+1]
  mov cl, byte [lines_len + bx]
  cmp byte [CURSOR], cl
  jae .move_cursor_to

  jmp .wait_for_key

.down:
  cmp byte [CURSOR+1], MAX_ROWS-1
  je .wait_for_key
  inc byte [CURSOR+1]

  movzx bx, byte [CURSOR+1]
  mov cl, byte [lines_len + bx]
  cmp byte [CURSOR], cl
  jae .move_cursor_to

  jmp .wait_for_key

; move_cursor_to(cl: u8 x_position)
.move_cursor_to:
  mov byte [CURSOR], cl
  jmp .wait_for_key

.return:
  cmp byte [CURSOR+1], MAX_ROWS -1
  je .wait_for_key

  inc byte [CURSOR+1]
  mov byte [CURSOR], 0
  jmp .wait_for_key

.backspace:
  cmp byte [CURSOR], 0
  je .wait_for_key                ; nop if beginning of line

  movzx bx, byte [CURSOR+1]
  mov cl, byte [lines_len + bx]   ; get line length
  
  cmp byte [CURSOR], cl           ; check if at end of line before decrementing
  je .at_end_of_line
  
  dec byte [CURSOR]
  mov al, 0x20
  call write_char
  jmp .write_and_redraw
  
.at_end_of_line:
  dec byte [lines_len + bx]       ; decrease line length
  dec byte [CURSOR]               ; move cursor back
  xor al, al                      ; null character
  
.write_and_redraw:
  mov cx, [CURSOR+1]
  call draw_line

  jmp .wait_for_key

; draw_cursor(void) -> void
; Positions the terminal cursor where the logical cursor is
draw_cursor:
  xor bh, bh        ; Page number = 0
  mov ah, 0x02      ; Set cursor position function
  mov dx, [CURSOR]
  int 0x10
  ret

; write_char(al: u8 char) -> void
; Writes the char in al at LINES_BUFFER_BASE[CURSOR.Y][CURSOR.X]
write_char:
  movzx bx, byte [CURSOR+1]
  mov cl, byte [lines_len + bx]         ; get line length
  mov dl, byte [CURSOR]
  cmp dl, cl
  jb .write_to_buffer                   ; increase length if end of line
  inc byte [lines_len + bx]
  
.write_to_buffer:
  push bx                               ; save line index
  shl bx, 6                             ; multiply by 64, line size
  lea di, [LINES_BUFFER_BASE + bx]                  ; get pointer to line
  pop bx                                ; restore line index
  movzx bx, byte [CURSOR]               ; put col (X) in bx
  mov byte [di + bx], al
  ret

; draw_buffer:
;   mov cx, MAX_ROWS - 1     ; Start from the last line
; .loop:
;   push cx
;   call draw_line
;   pop cx
;   dec cx                    ; Move to previous line
;   jns .loop                 ; Continue until cx becomes negative
;   ret

; draw_line(cl: u8 index)
; Draws line at index cl
draw_line:
  xor bh, bh                ; Page 0
  mov ah, 0x02              ; Set cursor position
  mov dh, cl                ; Row = cx (current line)
  xor dl, dl                ; Column = 0
  int 0x10

  movzx bx, cl
  movzx cx, byte [lines_len + bx]
  shl bx, 6                         ; multiply by 64, line size
  lea si, [LINES_BUFFER_BASE + bx]
  call print_buffer
  ret

; print_buffer(si: u8* string, cx: count) -> void
; Prints a buffer up to cx chars
print_buffer:
  mov ah, 0x0E    ; teletype function for interrupt 0x10
  xor bh, bh      ; page = 0
.loop:
  lodsb
  int 0x10
  loop .loop
.done:
  ret

CURSOR dw 0x0000

MAX_ROWS            equ 23
MAX_COLS            equ 64
LINES_BUFFER_BASE   equ 0x3000
lines_len           db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
