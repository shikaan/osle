// Welcome back!
//
// In the last part of our tutorial we will implement the `rm` utility: a
// program that deletes the file that is passed as argument. It will give us the
// chance to look at OSle's file system and do some error handling.
//
// Let's go!

// We know the drill now. This is how we include OSle's SDK in our program.
#include "../sdk/osle.h"

// Managing memory in OSle is straightforward. There is no malloc, no free; all
// memory is statically allocated and must be known at compile time. No memory
// leaks, hooray!
//
// To work with the file system, we need to allocate the memory for a file and
// its handle. Check out "sdk/osle.h" for more details on OSle's type definitions.
static file_t file;
static handle_t handle;

// These functions are used to exit the program. They should look very familiar
// except for a couple of calls. Check out "sdk/osle.h" to learn about them!
static inline void done(void) {
  putl("Press any key to return");
  (void)getc();
  exit();
}

static void error(const char *msg) {
  puts("rm: ");
  putl(msg);
  putl("Usage: rm FILE");
  done();
}

int main(int argc, char **argv) {
  // Let's start with some error checking.
  // We expect a filename as the only argument. Let's check that's the case.
  if (argc != 1) {
    error("unexpected number of arguments");
  }

  // Once we know there is an argument, we need to make sure it is a file.
  //
  // OSle provides the open() function to perform a lookup in the file system;
  // if the file is found, it populates the handle and file buffer, otherwise it
  // returns a non-zero value to signal failure.
  // You can read more about open() in "sdk/osle.h".
  char *filename = argv[0];

  if (0 != open(filename, &handle, &file)) {
    error("file not found");
  }

  // Deleting a file in OSle is a matter of zeroing its disk location. open()
  // loaded the file into our buffer; to delete it, we zero the entire buffer
  // and write it back to disk.
  for (int i = 0; i < FS_BLOCK_SIZE; i++) {
    ((byte_t *)&file)[i] = 0;
  }

  // Good job!
  //
  // Now we write the zeroed buffer back to disk. The handle we obtained from
  // open() tells write() which disk location to update.
  if (0 != write(handle, &file)) {
    error("cannot write on file");
  }

  // If everything went alright, we can let our users know.
  //
  // With this, you know all you need to start developing your OSle programs.
  // Take a look at the other utilities in `/bin` for more examples.
  //
  // Congratulations!
  //
  // If you have feedback on this course, or OSle in general, feel free to open
  // an issue https://github.com/shikaan/osle/issues/new
  putl("Success!");
  done();
}

// Once you are ready, compile and bundle this program in your OSle image with
//
//   sdk/occ tutorial/03-files.c
//   sdk/pack tutorial/03-files.bin
//
// Check out the README to make sure you have all the required dependencies.
