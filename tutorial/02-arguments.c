// Hello again!
//
// Our second program is just slightly more complex than the first one. We will
// code an `echo` program, where the user will pass a string as an argument and
// we will print it on the screen.
//
// Let's go!

// Once again, we include the OSle SDK in our program.
#include "../sdk/osle.h"

// Arguments arrive as argc and argv, just like a regular C program. Unlike what
// you might be used to, argv does not include the program name: argv[0] is the
// first actual argument.
int main(int argc, char **argv) {

  // Here we print each argument separated by a space, just like `echo` would.
  for (int i = 0; i < argc; i++) {
    if (i > 0) {
      putc(' ');
    }

    // puts prints a string without appending a new line. Check out "sdk/osle.h"
    // to learn more about printing functions.
    puts(argv[i]);
  }

  // As in the previous exercise, we tell the user how to leave the program.
  putl("");
  putl("Press any key to return");
  (void)getc();

  return 0;
}

// Once you are ready, compile and bundle this program in your OSle image with
//
//   sdk/occ tutorial/02-arguments.c
//   sdk/pack tutorial/02-arguments.bin
//
// Check out the README to make sure you have all the required dependencies.
