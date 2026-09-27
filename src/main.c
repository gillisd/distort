#include <config.h>

#include <argp.h>
#include <errno.h>
#include <error.h>
#include <stdlib.h>
#include <string.h>

#include "basename-lgpl.h"
#include "progname.h"

#include "distort.h"

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
    "Exit status: 0 on success, 1 on failure or a damaged stream, 64 on misuse.";

static const char args_doc[] = "encrypt [FILE]\ndecrypt [FILE]";

enum { OPT_USAGE = 256 };

static const struct argp_option options[] = {
    { "key-file", 'k', "FILE", 0, "read the 32-byte key (raw or hex) from FILE", 0 },
    { "cipher", 'c', "NAME", 0, "cipher to use; chacha20-poly1305 is the only one", 0 },
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
        puts(PACKAGE_STRING);
        exit(EXIT_SUCCESS);
    case 'k':
        a->key_file = arg;
        break;
    case 'c':
        if (strcmp(arg, "chacha20-poly1305") != 0)
            argp_error(state, "invalid cipher '%s' (expected chacha20-poly1305)", arg);
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

int main(int argc, char **argv)
{
    /* argp, getopt and error(3) all name the program after argv[0]. */
    argv[0] = last_component(argv[0]);
    set_program_name(argv[0]);

    struct args a = {};
    argp_parse(&argp, argc, argv, ARGP_NO_HELP, nullptr, &a);

    if (sodium_init() < 0)
        error(EXIT_FAILURE, 0, "cannot initialise libsodium");

    unsigned char key[KEY_BYTES];
    bool ok = run(&a, key);
    sodium_memzero(key, sizeof key);

    if (fclose(stdout) != 0 && ok) {
        error(0, errno, "write error");
        ok = false;
    }
    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
