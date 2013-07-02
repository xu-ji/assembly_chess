/* Xu Ji, Bora Mollamustafaoglu, Gun Pinyo (Imperial College London) 
 * {xj1112, bm1212, gp1712}@imperial.ac.uk
 * 
 * Created as part of our first year C project
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#define MAX_LINE_LENGTH 4096 // in bytes
#define MAX_NUM_SEQUENCES 40000
#define BGRND 'Q'

enum type {
  BACKGROUND = 0,
  PIECE,
  OUTLINE
};

static void fill_seqs(FILE *in);
static void print_seqs(FILE *out);
static enum type get_type(char c);


static size_t num_seqs;
static unsigned long int *sequences;
static char *buf;


int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr, "Usage: <ascii_input_file> <output_file>");
    exit(EXIT_FAILURE);
  }

  // handle input
  FILE *f_in = fopen(argv[1], "r");

  if (f_in == NULL) {
    fprintf(stderr, "Error opening input file");
    exit(EXIT_FAILURE);
  }

  sequences = malloc(MAX_NUM_SEQUENCES);
  if (sequences == NULL) {
    fprintf(stderr, "Error: insufficient memory");
    exit(EXIT_FAILURE);
  }

  buf = malloc(MAX_LINE_LENGTH + 1);
  if (buf == NULL) {
    fprintf(stderr, "Error: insufficient memory");
    exit(EXIT_FAILURE);
  }
  *(buf + MAX_LINE_LENGTH) = '\0';

  fill_seqs(f_in);
  fclose(f_in);
  free(buf);


  // handle output
  FILE *f_out = fopen(argv[2], "w");
  if (f_out == NULL) {
    fprintf(stderr, "Error opening output file");
    exit(EXIT_FAILURE);
  }


  print_seqs(f_out);
  fclose(f_out);
  free(sequences);

  return EXIT_SUCCESS;
}

/*
 * Takes an input file, which should contain ASCII art. This ASCII art is
 * split and interpreted to be either background (BGRND), which is given
 * a 0, piece (whitespace), which is given a 1, or outline (anything else),
 * which is given a 2.
 * Each character is converted into a DCD 0 or DCD 1 or DCD 2 command
 * accordingly, in order to generate the ARM7TDMI assembly code.
 */

/*Takes an input file, which should contain ASCII art.
 * The output will be many lines of DCD X, encoded in a special format:
 *    The very first DCD tells us the number of remaining words
 *      (array length - 1).
 *    Each DCD after that denotes a sequence, and is split into two parts:
 *        The bottom two bits tell us which element type we're encoding,
 *          which can be background (BGRND), which is given a 0, piece
 *          (whitespace), which is given a 1, or outline (anything else),
 *          which is given a 2. (3 is illegal)
 *        The remaining 30 bits tell us how many of that element are in that
 *          sequence.
 *
 */
static void fill_seqs(FILE *in) {
  enum type cur_type; // the character in the sequence we're currently in
  enum type tmp_type;
  int start = 1;
  int seq_length = 0; // length of current sequence

  num_seqs = 0;
  while (1) {
    // read a new line in
    buf = fgets(buf, MAX_LINE_LENGTH, in);
    if (buf == NULL) {
      // done - write the final sequence and quit
      long unsigned int res = (seq_length << 2) | cur_type;
      sequences[num_seqs++] = res;
      break;
    }
    // buffer now holds one line
    char *eol = strchr(buf, '\n');
    if (eol == NULL) {
      eol = strchr(buf, EOF);
      if (eol == NULL) {
        fprintf(stderr, "Error: unable to find end of line");
        exit(EXIT_FAILURE);
      }
    }
    *eol = '\0';


    // now we can process the line char by char
    char *c = buf;
    while (*c != '\0') {
      if (start) {
        cur_type = get_type(*c);   // init cur_type
        start = 0;
        continue;
      }
      if ((tmp_type = get_type(*c)) != cur_type) {

        long unsigned int res = (seq_length << 2) | cur_type;
        sequences[num_seqs++] = res;
        cur_type = tmp_type;
        // reset sequence length
        seq_length = 0;

      } else {
        seq_length++;
        c++;
      }
    }


  }
}

static void print_seqs(FILE *out) {
  fprintf(out, "    DCD      %u\n", (unsigned int)num_seqs);
  for (size_t i = 0 ; i < num_seqs ; i++) {
    fprintf(out, "    DCD      %lu\n",(unsigned long) sequences[i]);
  }
}

static enum type get_type(char c) {
  if (c == BGRND)
    return BACKGROUND;
  else if (isspace(c))
    return PIECE;
  else
    return OUTLINE;
}

