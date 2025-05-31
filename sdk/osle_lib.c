#include "osle_lib.h"

void print(const char* str) {
    // Print a string to the screen using BIOS interrupt 0x10
    // AH = 0x0E (teletype output)
    // AL = character to print
    while (*str) {
        asm volatile (
            ".code16\n"           // 16-bit kod olduğunu belirt
            "movb $0x0E, %%ah\n"  // b suffix ile 8-bit olduğunu belirt
            "movb %0, %%al\n"     // b suffix ile 8-bit olduğunu belirt
            "int $0x10\n"
            :
            : "q"(*str)           // "r" yerine "q" kullan (8-bit register)
            : "ax"
        );
        str++;
    }
}

// ...existing code...

void print_hex(u32 num) {
    // Print a number in hexadecimal format
    asm volatile (
        ".code16\n"              // 16-bit kod olduğunu belirt
        "movl %0, %%eax\n"       // l suffix ile 32-bit olduğunu belirt
        "int %1\n"
        :
        : "r"(num), "i"(INT_RETURN)
        : "eax"
    );
}

// ...existing code...

void println(const char* str) {
    // Print a string to the screen and add a new line at the end.
    // The string must be null-terminated.
    // The function will stop printing when it reaches the null terminator.
    // The string is stored in the data segment, so it must be in the format
    // "string" or 'string'.
    print(str);
    print("\n");
}

u32 string_lenght(const char* str) {
    // Returns the length of a string.
    // The string must be null-terminated.
    // The function will stop counting when it reaches the null terminator.
    // The string is stored in the data segment, so it must be in the format
    // "string" or 'string'.
    u32 len = 0;
    while (str[len] != '\0') {
        len++;
    }
    return len;
}

void string_copy(char* dest, const char* src) {
    // Copies a string from src to dest.
    // The string must be null-terminated.
    // The function will stop copying when it reaches the null terminator.
    // The string is stored in the data segment, so it must be in the format
    // "string" or 'string'.
    while ((*dest++ = *src++) != '\0');
}

void return_to_osle(void) {
    asm volatile (
        "int %0\n"
        : 
        : "i"(INT_RETURN)
    );
}