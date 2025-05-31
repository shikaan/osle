#include "osle_lib.h"
#include "number.h"

void main(void) {
    // Print a string to the screen.
    // The string must be null-terminated.
    // The function will stop printing when it reaches the null terminator.
    // The string is stored in the data segment, so it must be in the format
    // "string" or 'string'.
    print("Hello, world!\n");
    
    // Return control back to OSle.
    return_to_osle();
}