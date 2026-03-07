#include "osle.h"

extern int main(int argc, char **argv);

#define MAX_ARGS 16
static int argc = 0;
static char *argv[MAX_ARGS] = {};

__attribute__((naked, section(".text.epilogue"), noreturn)) void
__epilogue(void) {
  __asm__ volatile("int %0" ::"N"(INT_RETURN) :);
}

__attribute__((section(".text.prologue"), noreturn)) void __prologue(void) {
  // Clean the screen and put the cursor top-left
  __asm__ volatile("mov $0x0003, %%ax\n"
                   "int $0x10" ::
                       : "ax");

  // Read arguments
  char *args = (char *)PM_ARGS;

  argc = 0;
  for (int i = 0; args[i]; i++) {
    if (args[i] == ' ') {
      args[i] = 0;
    } else if (i == 0 || args[i - 1] == 0) {
      if (argc < MAX_ARGS - 1) {
        argv[argc++] = &args[i];
      } else {
        break;
      }
    }
  }

  main(argc, argv);
  __epilogue();
}
