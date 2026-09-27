#include <config.h>

#include <argp.h>
#include <errno.h>
#include <error.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "basename-lgpl.h"

#include "distort.h"

const char *argp_program_version =
    PACKAGE_STRING "\n"
    "Copyright (c) 2026 David Gillis\n"
    "License: MIT <https://opensource.org/licenses/MIT>";
const char *argp_program_bug_address = PACKAGE_BUGREPORT;

static const char doc[] =
    "Encrypt or decrypt a stream with authenticated encryption."
    "\v"
    "With no FILE, or when FILE is -, read standard input.  Write to standard output.\n"
    "\n"
    "Examples:\n"
    "  tar cz dir | distort encrypt -k key.key > dir.tgz.enc\n"
    "  distort decrypt -k key.key < dir.tgz.enc | tar xz\n"
    "  distort encrypt -k key.key notes.txt > notes.txt.enc\n"
    "\n"
    "Make a key:  head -c 32 /dev/urandom > key.key\n"
    "\n"
    "Exit status is 0 on success, 1 on failure, 64 on a usage error.";

static const char args_doc[] = "-k FILE {encrypt|decrypt} [FILE]";

enum { OPT_USAGE = 256 };

static const struct argp_option options[] = {
    { "key-file", 'k', "FILE", OPTION_NO_USAGE, "read the 32-byte key from FILE; required", 0 },
    { "cipher", 'c', "NAME", 0, "cipher to use; xchacha20-poly1305 is the only one", 0 },
    { "help", 'h', nullptr, 0, "give this help list", -1 },
    { "usage", OPT_USAGE, nullptr, 0, "give a short usage message", -1 },
    { "version", 'V', nullptr, 0, "print program version", -1 },
    {},
};

enum command { CMD_NONE, CMD_ENCRYPT, CMD_DECRYPT };

struct args {
    enum command command;
    const char *key_file;
    const char *input;
};

static error_t parse_opt(int key, char *arg, struct argp_state *state)
{
    struct args *a = state->input;

    switch (key) {
    case 'h':
        argp_state_help(state, stdout, ARGP_HELP_STD_HELP);
        break;
    case OPT_USAGE:
        argp_state_help(state, stdout, ARGP_HELP_USAGE | ARGP_HELP_EXIT_OK);
        break;
    case 'V':
        puts(argp_program_version);
        exit(EXIT_SUCCESS);
    case 'k':
        a->key_file = arg;
        break;
    case 'c':
        if (strcmp(arg, "xchacha20-poly1305") != 0)
            argp_error(state, "invalid cipher '%s' (expected xchacha20-poly1305)", arg);
        break;
    case ARGP_KEY_ARG:
        if (state->arg_num == 0) {
            if (strcmp(arg, "encrypt") == 0)
                a->command = CMD_ENCRYPT;
            else if (strcmp(arg, "decrypt") == 0)
                a->command = CMD_DECRYPT;
            else
                argp_error(state, "unknown command '%s'", arg);
        } else if (state->arg_num == 1) {
            a->input = arg;
        } else {
            argp_error(state, "too many arguments");
        }
        break;
    case ARGP_KEY_NO_ARGS:
        argp_error(state, "missing command");
        break;
    case ARGP_KEY_END:
        if (a->key_file == nullptr)
            argp_error(state, "missing required option --key-file");
        break;
    default:
        return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static const struct argp argp = { options, parse_opt, args_doc, doc, nullptr, nullptr, nullptr };

static bool run(const struct args *a, unsigned char key[KEY_BYTES])
{
    if (!key_load(a->key_file, key))
        return false;

    FILE *in = stdin;
    const char *in_name = "(standard input)";
    if (a->input != nullptr && strcmp(a->input, "-") != 0) {
        in_name = a->input;
        in = fopen(in_name, "rb");
        if (in == nullptr) {
            error(0, errno, "%s", in_name);
            return false;
        }
    }

    bool ok = a->command == CMD_ENCRYPT
                  ? stream_encrypt(in, in_name, stdout, key)
                  : stream_decrypt(in, in_name, stdout, key);
    if (in != stdin)
        fclose(in);
    return ok;
}

static void print_program_name(void)
{
    fprintf(stderr, "%s: ", getprogname());
}

/* Flush and close stdout at exit, so that no write error goes unreported.
   As with gnulib's close_stdout, a stdout that was closed from the start is
   no error when there was nothing to write to it.  */
static void close_stdout(void)
{
    bool flush_failed = fflush(stdout) != 0;
    if (flush_failed || ferror(stdout)) {
        int err = flush_failed ? errno : 0;
        if (err != EPIPE)
            error(0, err, "write error");
        _exit(EXIT_FAILURE);
    }
    if (fclose(stdout) != 0 && errno != EBADF) {
        /* stdout is gone, so error(), which flushes it first, cannot be used. */
        if (errno != EPIPE)
            fprintf(stderr, "%s: write error: %s\n", getprogname(), strerror(errno));
        _exit(EXIT_FAILURE);
    }
}

int main(int argc, char **argv)
{
    /* Name the program without its directory: argp and getopt use argv[0]. */
    argv[0] = last_component(argv[0]);
    error_print_progname = print_program_name;
    atexit(close_stdout);
    /* Buffer stdout fully unless it is a terminal, as glibc does, so that a
       write error surfaces when stdout is flushed, with its errno.  */
    if (!isatty(STDOUT_FILENO))
        setvbuf(stdout, nullptr, _IOFBF, BUFSIZ);

    struct args a = {};
    argp_parse(&argp, argc, argv, ARGP_NO_HELP, nullptr, &a);

    if (a.command == CMD_ENCRYPT && isatty(STDOUT_FILENO))
        error(EXIT_FAILURE, 0, "refusing to write encrypted data to a terminal");
    if (a.command == CMD_DECRYPT && (a.input == nullptr || strcmp(a.input, "-") == 0)
        && isatty(STDIN_FILENO))
        error(EXIT_FAILURE, 0, "refusing to read encrypted data from a terminal");

    if (sodium_init() < 0)
        error(EXIT_FAILURE, 0, "cannot initialise libsodium");

    unsigned char key[KEY_BYTES];
    bool ok = run(&a, key);
    sodium_memzero(key, sizeof key);
    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
