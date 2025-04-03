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

; Set up stack
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

  push 0x0101
  call set_cursor

  push text
  call println

  cli
  hlt

; clear(void)
clear:
  fn_start

  mov ax, 0x0700 ; Scroll Down and clear window
  mov cx, 0x0000 ; Set top left corner in 0,0
  mov dx, 0x184F ; Set bottom right corner in 18,4F
  mov bh, 0x07   ; Set color 
  int 0x10

  fn_end

; set_cursor(di: col_row)
set_cursor:
  fn_start
    mov dx, [bp+4] 
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
  fn_end

; get_cursor(void) -> (ax: col_row)
get_cursor:
  fn_start
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    mov ax, dx
  fn_end

; put_char(u8 char)
put_char:
  fn_start
    mov ax, [bp+4] 
    mov ah, 0x0A
    mov bh, 0x00
    mov cx, 1
    int 0x10
  fn_end

; println(u8 *string)
println:
  fn_start
    mov si, [bp+4]

  .loop:
    mov al, [si]
    cmp al, 0
    je .break
    push ax
    call put_char
    inc si
    call get_cursor
    add al, 1
    push ax
    call set_cursor
    jmp .loop

  .break:
    fn_end

text: db "You have successfully launched a bootloader. Joy!", 0

times 510-($-$$) db 0
dw 0xAA55
