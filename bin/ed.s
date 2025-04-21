%macro debugger 0
  xchg bx,bx
%endmacro

bits 16

mov ax, 0x0003
int 0x10

mov dx, CURSOR_INIT
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
  call arrow.right
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
  je .handled                       ; don't move left if start of line
  dec dl
  jmp .update

.right:
  movzx bx, dh
  cmp dl, byte [line_length + bx]
  jae .handled                       ; don't move right if end of line
  
  inc dl
  jmp .update

.up:
  cmp dh, 1
  je .handled
  dec dh
  call clamp_to_line
  jmp .update

.down:
  cmp dh, MAX_ROWS-1
  je .handled

  movzx bx, dh
  inc bx
  cmp byte [line_length + bx], 0
  je .handled                       ; if next line is empty, don't go down

  inc dh
  call clamp_to_line
  jmp .update

.update:
  call set_cursor
.handled:
  stc
  ret

; arrow(ax: u16 input, dh: line, dl: column)
; Handles control keys. Sets carry flag if input is handled
control_key:
  cmp ax, 0x0e08 ; backspace
  je .backspace
  cmp ax, 0x1c0D ; enter
  je .return
  cmp ax, 0x0f09 ; tab
  je .handled
  clc
  ret

.backspace:
  cmp dl, 0
  je .handled

  call get_buffer_position                            ; if deleting CRLF, remove both chars
  mov bx, ax
  sub bx, 2
  mov ax, word [FILE_BUFFER + FILE_HEADER_SIZE + bx]
  cmp ax, CRLF
  jne .delete_once

  call delete_char
  call arrow.left

.delete_once:
  call delete_char
  call arrow.left

  call print_buffer
  jmp .handled

.return:
  cmp dh, MAX_ROWS-1
  je .handled
  mov al, 0x0D
  call insert_char
  mov al, 0x0A
  call insert_char
  call print_buffer
  inc dh
  mov dl, 0
  call set_cursor
  ; cascades

.handled:
  stc
  ret

; print_char(al: u8)
; Prints printable charachters plus carriage return, line feed, and null byte.
print_char:
  pusha
    cmp al, 0x0D
    je .print
    cmp al, 0x0A
    je .print
    cmp al, 0x00
    je .null

    cmp al, 32
    jb .done
    cmp al, 126
    ja .done
    jmp .print

.null:
    mov al, 0XFE
    jmp .print

.print:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
.done:
  popa
  ret

; insert_char(al: u8 char, dh: line, dl: column)
; Insert the char in al at the cursor position, moving the buffer around it.
insert_char:
  push ax
    call get_buffer_position
    mov di, ax
  pop ax
  push di
    call push_right
  pop di
  mov byte [FILE_BUFFER + FILE_HEADER_SIZE + di], al

  movzx bx, dh
  inc word [file_data_len]
  ret

; delete_char(dh: line, dl: column)
; Deletes the char at the cursor position, moving the buffer around it.
delete_char:
  call get_buffer_position
  mov di, ax
  call shift_left
  movzx bx, dh
  dec word [file_data_len]
  ret

; push_right(di: u16 logical_position)
; Pushes the file buffer right from a given logical position
;      buf: 11 22 33 44, di: 1
;   becomes
;     11 22 22 33 44
push_right:
  mov bx, MAX_LEN - 1
  mov cx, bx
  sub cx, di
  inc cx
  lea si, [FILE_BUFFER + FILE_HEADER_SIZE + bx]
  lea di, [FILE_BUFFER + FILE_HEADER_SIZE + bx + 1]
  std
  repe movsb
  cld
  ret

; shift_left(di: u16 logical_position)
; Shifts the file buffer left from a given logical position
;      buf: 11 22 33 44, di: 1
;   becomes
;     11 33 44
shift_left:
  mov bx, di
  dec bx
  mov cx, MAX_LEN
  sub cx, bx
  lea si, [FILE_BUFFER + FILE_HEADER_SIZE + bx + 1]
  lea di, [FILE_BUFFER + FILE_HEADER_SIZE + bx]
  cld
  repe movsb
  std
  ret

; get_buffer_position(dh: line, dl: column)
; Takes a visual cursor position and returns its logical position in the buffer
; The calculation is: pos = sum(length of lines before current) + cursor
get_buffer_position:
  xor ax, ax                        ; ax will be the position in the buffer  
  movzx bx, dh
  cmp dh, 1
  jbe .current_line                 ; no sum of previous lines, if is first
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
; Returns current visual cursor position
get_cursor:
  mov ah, 0x03
  xor bh, bh
  int 0x10
  ret

; set_cursor(dh: line, dl: column) -> void
; Sets visual cursor position
set_cursor:
  mov ah, 0x02      ; Set cursor position function
  xor bh, bh        ; Page number = 0
  int 0x10
  ret

; clamp_to_line(dh: line, dl: column)
; Clamps cursor coordinates within the current line. Does not update the cursor!
clamp_to_line:
  push bx
    movzx bx, dh
    cmp dl, byte [line_length + bx]
    jbe .done
    mov dl, byte [line_length + bx]
.done:
  pop bx
  ret

; print_buffer(void)
; Prints the entire buffer on screen, saving the cursor position.
print_buffer:
  call get_cursor
  push dx
    mov ax, 0x0600                  ; scroll up and clear window
    xor cx, cx                      ; top left corner = 0,0
    mov dx, 0x184F                  ; bottom right corner = 18,4F
    mov bh, 0x07                    ; set background color
    int 0x10                        ; clear screen

    mov dx, CURSOR_INIT
    call set_cursor
    lea si, [FILE_BUFFER + FILE_HEADER_SIZE]
    mov cx, [file_data_len]
    inc cx                          ; null terminate printing
.loop:
    mov al, byte [si]
    call print_char
    inc si
    loop .loop
.done:
  pop dx
  call set_cursor
  call recalculate_line_lengths
  ret

; recalculate_line_lengths(void)
; Recalculates the line lengths in the buffer which might have changed as a
; result of adding or removing chars
recalculate_line_lengths:
  pusha
    mov di, 1                         ; line index
    mov bx, 0                         ; buffer index
    mov dl, 0                         ; column index (index on a line)
    mov cx, [file_data_len]
.loop:
    mov ax, word [FILE_BUFFER + FILE_HEADER_SIZE + bx]
    cmp ax, CRLF
    je .new_line
    inc bx
    inc dl
    jmp .continue
.new_line:
    add dl, 2                         ; account for crlf in column index
    add bx, 2                         ; account for crlf in buffer index
    dec cx                            ; account for cflf in the loop counter
    mov byte [line_length + di], dl
    inc di
    mov dx, 0
    ; cascade
.continue:
    loop .loop
    mov byte [line_length + di], dl
  popa
  ret

MAX_ROWS            equ 23
MAX_COLS            equ 80
MAX_LEN             equ MAX_COLS * MAX_ROWS
FILE_HEADER_SIZE    equ 24
FILE_BUFFER         equ 0x2000
CURSOR_INIT         equ 0x0100
CRLF                equ 0x0D0A
file_data_len       dw 0x0000
line_length         times MAX_ROWS db 0

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
