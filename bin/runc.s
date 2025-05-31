bits 16
%include "sdk/osle.inc"

; Ekranı temizle
mov ah, 0x00
mov al, 0x03
int 0x10

; Dosyayı bul ve yükle
mov di, PM_ARGS
mov bx, FILE_BUFFER
int INT_FS_FIND
jc not_found

jmp run_loaded

not_found:
    mov si, ERR_NOT_FOUND
    mov cx, 0xFF
    call str_print
    jmp wait_exit

run_loaded:
    ; Stack frame'i hazırla
    mov bp, sp
    sub sp, 2              ; Local değişkenler için yer ayır
    
    ; Data segmentini ayarla
    mov ax, ds
    mov es, ax
    
    ; Stack'i ayarla
    mov sp, 0xFFFE
    
    ; Main'i çağır
    mov ax, FILE_BUFFER
    add ax, FS_DATA_OFFSET
    call ax               ; jmp yerine call kullan
    
    ; Main'den döndükten sonra
    add sp, 2            ; Stack'i temizle
    jmp wait_exit        ; Program bitişine git

wait_exit:
    mov si, RETURN
    mov cx, 0xFF
    call str_print
    mov ax, 0
    int 0x16
    int INT_RETURN

str_print:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    je .done
    int 0x10
    loop .loop
.done:
    popa
    ret

ERR_NOT_FOUND: db "File not found!", 0
RETURN:        db 0x0a, 0x0d, "Press any key to return", 0
FILE_BUFFER    equ 0x4000