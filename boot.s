; Calling convention
;   - max two arguments per function (else stack): di, si;
;   - function preserves bx;
;   - invoker preserves ax, cx, dx, di, si;
;   - ax is the return register;
%macro frame_start 0
  push bp
  mov bp, sp
  push bx
%endmacro

%macro frame_end 0
  pop bx
  mov sp, bp
  pop bp
  ret
%endmacro

%macro fn_start 0
  push bx
%endmacro

%macro fn_end 0
  pop bx
  ret
%endmacro

bits 16

.setup_memory:
  mov ax, 0x7C0   ; data segment
  mov ds, ax

  mov ax, 0x7E0   ; stack segment
  mov ss, ax

  mov sp, 0x2000  ; stack pointer (stack size = 8k)

.setup_screen:
  mov ax, 0x0003    ; 0x00: Set video mode, 80x25 text mode, color
  int 0x10

.main:
  call scr_clear
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
  mov di, 0
  call cur_set
  
  .print_prompt:
    mov di, '$'
    call scr_put_char
    mov di, 2
    call cur_move

  .loop:
    call kbd_get_key
    cmp al, 0x0D        ; key is ENTER jump to cmd
    je .cmd
    cmp al, 0x08        ; key is BACKSPACE
    je .backspace
    jne .print_char     ; else, try to print

  .print_char:
    push ax
    mov di, input
    mov si, ax
    call str_append     ; append new character to the input buffer
    pop di
    call scr_put_char   ; write the new character on screen
    mov di, 1
    call cur_move       ; move the cursor forward
    jmp .loop

  .backspace:
    mov di, -1
    call cur_move       ; move cursor backwards
    mov di, 0
    call scr_put_char   ; remove the character from screen
    mov di, input
    call str_remove     ; remove character from input buffer
    jmp .loop
  
  .cmd:
    call cur_return     ; carriage return
    mov di, input
    mov si, CLEAR
    call str_compare    
    je .cmd_clear       ; command is the builtin clear
    jmp .cmd_error      ; command is unknown

    .cmd_clear:
      call scr_clear
      mov di, 0
      call cur_set
      jmp .print_prompt

    .cmd_error:
      mov si, ERROR
      mov di, output
      call str_copy
      mov di, output
      call str_print

    .cmd_done:
      call cur_return
      mov di, input
      call str_empty
      mov di, output
      call str_empty
      jmp .print_prompt

  .break: ret


; Keyboard
; --------

; kbd_get_key(void) -> (ax: u16 scan_code|key_code)
; Waits for a key press and returns the key code in al and scan code in ah
kbd_get_key:
  mov ah, 0x00  ; Function 0: Read character
  int 0x16
  ret

; String
; ------

; Strings are buffers prefixed with 2 bytes: capacity and size. The first
; represents the size of the allocated buffer, the latter how much of it has
; been used. Strings should never be read beyond the `size` value. 

; str_append(di: u8* string, si: u8 char)
; Appends a char to a given string
str_append:
  fn_start
    mov cl, [di + 1]      ; cl = size
    cmp cl, [di]          ; compare with capacity
    jae .end              ; if size >= capacity, return
    
    xor bx, bx            ; scr_clear bx
    mov bl, cl            ; use size as index
    inc byte [di + 1]     ; increment size
    mov [di + bx + 2], si ; store char at buffer[index + 2]     
  .end:
    fn_end

; str_remove(di: u8* string)
; Removes last byte from a string
str_remove:
  mov cl, [di + 1]  ; cl = size 
  cmp cl, 0         ; if size == 0, return
  je .end 
  dec byte [di + 1]
  .end: 
    ret

; str_empty(di: u8* string)
; Makes a string empty
str_empty:
  mov byte [di + 1], 0
  ret 

; str_compare(di: u8* string, si: u8* string)
; Compares two trings setting the Z flag accordingly
str_compare:
  mov al, [di + 1]
  cmp al, [si + 1]              ; if size differs, return (Z=false)
  jne .end
  mov bx, 0                     ; bx = counter
  
  .loop:
    mov al, [bx + di + 2]
    cmp al, [bx + si + 2]       ; if byte differs, return (Z=false)
    jne .end
    inc bx
    cmp bl, byte [di + 1]       ; if counter == size, return (Z=true)
    je .end
    jmp .loop

  .end:
    ret

; str_print(di: u8 *string) -> void
; Prints a string to the screen
str_print:
  frame_start
    mov bx, 0               ; bx = counter

    .loop:
      cmp byte [di + 1], bl ; if counter == size, return
      je .break
      push di               ; save di before rewriting
      mov di, [di + bx + 2]
      call scr_put_char
      mov di, 1
      call cur_move
      pop di
      inc bx
      jmp .loop

    .break:
      frame_end

; str_copy(di: u8 *dest, si: u8 *src) -> void
; Copies a string entirely from the source into the destination
str_copy:
  fn_start
    mov dl, byte [si + 1] 
    cmp dl, byte [di]             ; when dest capacity is smaller than src size
    ja .end                       ; we don't have enough space, so we return
    mov byte [di + 1], dl
    xor bx, bx

    .loop:
      cmp byte [si + 1], bl       
      je .end
      mov cl, byte [si + bx + 2]  ; copy the byte
      mov byte [di + bx + 2], cl
      inc bx
      jmp .loop

    .end:
      fn_end

; Cursor
; ------
; cur_set(di: u16 col|row)
; Sets the cursor position on the screen. Low byte is column, high byte is row.
cur_set:
  fn_start
    mov dx, di
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
  fn_end

; cur_get(void) -> (ax: u16 col|row)
; Returns the current cursor position.
cur_get:
  fn_start
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    mov ax, dx
  fn_end

; cur_move(di: i8 delta_col|delta_row)
; Moves the cursor in the current page.
cur_move:
  call cur_get
  add ax, di
  mov di, ax
  call cur_set
  ret

; cur_return(void)
; Moves the cursor at the beginning of the next line
cur_return:
  call cur_get
  inc ah        ; move one line down
  mov al, 0
  mov di, ax
  call cur_set
  ret

; Screen
; ------

; scr_clear(void)
; Clears the screen and scrolls the window up.
scr_clear:
  fn_start
    mov ax, 0x0600 ; scroll up and clear window
    mov cx, 0x0000 ; top left corner = 0,0
    mov dx, 0x184F ; bottom right corner = 18,4F
    mov bh, 0x07   ; set background color
    int 0x10
  fn_end

; scr_put_char(di: u8 char) -> void
; Puts a character to the screen at the current cursor position.
scr_put_char:
  fn_start
    mov ax, di
    mov ah, 0x0A  ; 0A: write character
    mov bh, 0x00  ; page = 0
    mov cx, 1     ; how many repetitions?
    int 0x10
  fn_end

; Data
; ====
input:  db 0x20, 0x00
        times 0x20 db 0

output: db 0x20, 0x00
        times 0x20 db 0

CLEAR: db 0x5,0x5,"clear"
ERROR: db 0x13,0x13,"sh: unknown command"

times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
