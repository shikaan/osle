// Hello!
// This little example will guide you through writing your first OSle program
// in C.
//
// As tradition demands, our first program will be a "Hello World". Our program
// prints "Hello world" on screen and, on pressing any key, returns to the OS.
//
// Let's go!

// Here we are including the OSle SDK.
// OSle's SDK provides all the functions and types you need to interact with the
// OS: printing, reading input, working with files, and more.
#include "../sdk/osle.h"

// This is the entry point of our program. Every OSle program starts with a main
// function. We can ignore its arguments for now; we will discuss them in the
// next lesson.
int main(int argc, char **argv) {
  // Aha! We already reached the core of our program!
  // putl (put line) is a function to put a string on the screen.
  // Check out "sdk/osle.h" to read more about it.
  putl("Hello, world!");

  // We are done; time to return control to the OS.
  //
  // OSle is a cooperative OS: every time you launch a process, it takes over
  // your machine and control must explicitly be returned to the OS. Once a
  // process returns, the OS reclaims the machine entirely — there is no
  // process to resume.
  //
  // This means that as soon as we return, the message above will be gone. We
  // need to pause and wait for the user to press a key before returning.
  putl("Press any key to return");

  // getc waits for a key press and returns the character. We don't need the
  // character itself, so we discard it.
  (void)getc();

  // When main returns, OSle takes back control automatically.
  return 0;
}

// Once you are ready, compile and bundle this program in your OSle image with
//
//   sdk/occ tutorial/01-hello.c
//   sdk/pack tutorial/01-hello.bin
//
// Check out the README to make sure you have all the required dependencies.
