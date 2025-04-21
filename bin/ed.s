%macro debugger 0
  xchg bx,bx
%endmacro

bits 16

  mov ax, 0x0003
  int 0x10

mov dx, 0x0100
call set_cursor

wait_for_key:
  xor ax, ax
  int 0x16

  call arrow
  jc wait_for_key

  call control_key
  jc wait_for_key

  call insert_char
  call print_buffer
  call arrow.right ; todo: this should only happen for printables
  jmp wait_for_key

; arrow(ax: u16 input, dh: line, dl: column)
; Sets carry flag if input is handled
arrow:
  push ax
    call get_cursor
  pop ax
  cmp ax, 0x4B00
  je .left
  cmp ax, 0x4D00
  je .right
  cmp ax, 0x4800
  je .up
  cmp ax, 0x5000
  je .down
  clc
  ret

.left:
  cmp dl, 0
  je .done                          ; don't move left if start of line
  dec dl
  jmp .update

.right:
  movzx bx, dh
  cmp dl, byte [line_length + bx]
  jae .done                         ; don't move right if end of line
  
  inc dl
  jmp .update

.up:
  cmp dh, 1
  je .done
  dec dh
  call clamp_to_line
  jmp .update

.down:
  cmp dh, MAX_ROWS-1
  je .done

  movzx bx, dh
  inc bx
  cmp byte [line_length + bx], 0
  je .done                       ; if next line is empty, don't go down

  inc dh
  call clamp_to_line
  jmp .update

.update:
  call set_cursor
.done:
  stc
  ret

control_key:
  cmp ax, 0x0e08 ; backspace
  je .handled
  cmp ax, 0x1c0D ; enter
  je .handled
  cmp ax, 0x0f09 ; tab
  je .handled
  clc
  ret
.handled:
  stc
  ret
  

; print_char(al: u8)
; print printable char
print_char:
  pusha
    cmp al, 0x0D
    je .print
    cmp al, 0x0A
    je .print
    cmp al, 0x00
    je .print

    cmp al, 32
    jb .done
    cmp al, 126
    ja .done
.print:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
.done:
  popa
  ret

; insert_char(al: u8 char, dh: line, dl: column)
; pos = sum (lines before this) + cursor
insert_char:
  push ax
    call get_buffer_position
    mov di, ax
  pop ax
  push di
    call push_right
  pop di
  mov byte [FILE_BUFFER + 24 + di], al

  movzx bx, dh
  inc byte [line_length + bx]
  ret


; splits the buffer at di and pushes the right-hand side by one to accommodate
; for a new character
push_right:
  mov bx, MAX_LEN - 1
  mov cx, bx
  sub cx, di
  inc cx
  lea si, [FILE_BUFFER + 24 + bx]
  lea di, [FILE_BUFFER + 24 + bx + 1]
  std
  repe movsb
  cld
  ret


; returns the logical position in the buffer corresponding to the current
; cursor position
get_buffer_position:
  xor ax, ax                        ; ax will be the position in the buffer  
  movzx bx, dh
  cmp dh, 0
  jmp .current_line                 ; no sum of previous lines, if is first
  movzx cx, dh                      ; repeat dh times
  dec bx                            ; previous lines, not current
.sum_loop:
  add al, byte [line_length + bx]
  dec bx
  loop .sum_loop
.current_line:
  add al, dl
  ret

; get_cursor() -> (dh: line, dl: column)
get_cursor:
  mov ah, 0x03
  xor bh, bh
  int 0x10
  ret

; set_cursor(dh: line, dl: column) -> void
set_cursor:
  mov ah, 0x02      ; Set cursor position function
  xor bh, bh        ; Page number = 0
  int 0x10
  ret

; clamp_to_line()
; Clamps curor coordinates within the current line. Does not update the cursor!
clamp_to_line:
  push bx
    movzx bx, dh
    cmp dl, byte [line_length + bx]
    jbe .done
    mov dl, byte [line_length + bx]
.done:
  pop bx
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

MAX_ROWS            equ 23
MAX_COLS            equ 80
MAX_LEN             equ 1840
FILE_BUFFER         equ 0x2000
line_length         times MAX_ROWS db 0