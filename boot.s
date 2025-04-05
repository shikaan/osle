; Calling convention
;   - max two arguments per function (else stack): di, si;
;   - function preserves bx;
;   - invoker preserves ax, cx, dx, di, si;
;   - ax is the return register;
%macro fn_start 0
  push bp
  mov bp, sp
  push bx
%endmacro

%macro fn_end 0
  pop bx
  mov sp, bp
  pop bp
  ret
%endmacro

bits 16

.setup_memory:
  mov ax, 0x7C0 ; Data Segment
  mov ds, ax

  mov ax, 0x7E0 ; Stack Segment
  mov ss, ax

  mov sp, 0x2000 ; Stack size: 8k (0x2000 is 8192)

.setup_screen:
  mov ah, 0x00 ; Function 0: Set video mode
  mov al, 0x03 ; 80x25 text mode, color
  int 0x10

.main:
  call clear
  call shell

  cli
  hlt

; Definitions
; ===========

; Shell
; -----

; shell(void)
; Launches an interactive command prompt, the entry point of our real-mode OS.
shell:
  fn_start
    mov di, 0
    call set_cursor
    mov di, '$'
    call put_char
    mov di, 2
    call move_cursor

    .loop:
      call get_key
      cmp al, 0x0D
      je .enter
      cmp al, 0x08
      je .backspace
      jne .print_char

    .print_char:
      mov di, ax
      call put_char
      mov di, 1
      call move_cursor

      jmp .loop

    .enter:
      jmp .break

    .backspace:
      mov di, -1
      call move_cursor
      mov di, 0
      call put_char
      jmp .loop

  .break:
  fn_end


; Keyboard
; --------

; get_key(void) -> (ax: u16 key)
; Waits for a key press and returns the key code in AX.
get_key:
  fn_start
    mov ah, 0x00
    int 0x16
  fn_end

; Cursor
; ------

; set_cursor(di: u16 col_row)
; Sets the cursor position on the screen. Low byte is column, high byte is row.
set_cursor:
  fn_start
    mov dx, di
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
  fn_end

; get_cursor(void) -> (ax: u16 col_row)
; Returns the current cursor position.
get_cursor:
  fn_start
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    mov ax, dx
  fn_end

; move_cursor(di: i8 delta)
; Moves the cursor forward in the current page
move_cursor:
  fn_start
    call get_cursor
    add ax, di
    mov di, ax
    call set_cursor
  fn_end

; Screen
; ------

; clear(void)
; Clears the screen and scrolls the window up.
clear:
  fn_start
    mov ax, 0x0600 ; Scroll up and clear window
    mov cx, 0x0000 ; Set top left corner in 0,0
    mov dx, 0x184F ; Set bottom right corner in 18,4F
    mov bh, 0x07   ; Set color for the background
    int 0x10
  fn_end

; put_char(di: u8 char) -> void
; Prints a single character to the screen at the current cursor position.
put_char:
  fn_start
    mov ax, di
    mov ah, 0x0A
    mov bh, 0x00
    mov cx, 1
    int 0x10
  fn_end

; print_string(di: u8 *string, si: u8 size) -> void
; Prints a length prefixed string, one character at a time.
print:
  fn_start
    mov bx, di  ; bx = buffer
    mov cx, 0   ; cx = counter
    mov dx, si  ; dx = size

  .loop:
    cmp dl, cl
    je .break
    cmp byte [bx], cl
    je .break
    push cx
    push dx
    mov si, cx
    mov di, [bx + si + 1]
    call put_char
    mov di, 1
    call move_cursor
    pop dx
    pop cx
    inc cx
    jmp .loop

  .break:
    fn_end

; Data
; ====
input:  db 0x40
        times 0x40 db 0

output: db 0x40
        times 0x40 db 0

times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
