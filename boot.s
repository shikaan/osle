%macro fn_start 0
  push bp
  mov bp, sp
%endmacro

%macro fn_end 0
  mov sp, bp
  pop bp
  ret
%endmacro

bits 16

_setup:
  .prepare_stack:
     mov ax, 0x7C0 ; Data Segment
     mov ds, ax

     mov ax, 0x7E0 ; Stack Segment
     mov ss, ax

     mov sp, 0x2000 ; Stack size: 8k (0x2000 is 8192)

  .prepare_video:
     mov ah, 0x00 ; Function 0: Set video mode
     mov al, 0x03 ; 80x25 text mode, color
     int 0x10

_main:
  call clear

  mov di, 0x0101
  call set_cursor

  mov di, text
  call println

  cli
  hlt

; clear(void) -> void
; Clears the screen and scrolls the window up.
clear:
  fn_start
    mov ax, 0x0600 ; Scroll up and clear window
    mov cx, 0x0000 ; Set top left corner in 0,0
    mov dx, 0x184F ; Set bottom right corner in 18,4F
    mov bh, 0x07   ; Set color for the background
    int 0x10
  fn_end

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

; println(di: u8 *string) -> void
; Prints a null-terminated string to the screen, one character at a time.
println:
  fn_start
    mov si, di ; Save the string pointer

  .loop:
    mov al, [si]
    cmp al, 0
    je .break
    mov di, ax
    call put_char
    inc si
    call get_cursor
    add al, 1
    mov di, ax
    call set_cursor
    jmp .loop

  .break:
    fn_end

text: db "You have successfully launched a bootloader. Joy!", 0

times 510-($-$$) db 0
dw 0xAA55
