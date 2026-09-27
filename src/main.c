#include <config.h>

#include <argp.h>
#include <errno.h>
#include <error.h>
#include <stdlib.h>
#include <string.h>

#include "basename-lgpl.h"
#include "progname.h"

#include "distort.h"

const char *argp_program_version = PACKAGE_STRING;
const char *argp_program_bug_address = PACKAGE_BUGREPORT;

static const char doc[] =
    "Encrypt or decrypt a stream with authenticated encryption."
    "\v"
    "Reads FILE, or standard input when FILE is absent or -, and writes to standard "
    "output. Data is processed in 64 KiB chunks, so memory use is constant.\n"
    "\n"
    "The cipher is XChaCha20-Poly1305, via libsodium's crypto_secretstream; "
    "chacha20-poly1305 is the only CIPHER.\n"
    "\n"
    "The key file holds 32 random bytes, raw or as 64 hex digits; make one with\n"
    "  head -c 32 /dev/urandom > key.key\n"
    "\n"
    "Exit status is 0 on success, 1 on failure (including authentication "
    "failure), and 64 on a usage error.";

static const char args_doc[] = "encrypt [FILE]\ndecrypt [FILE]";

static const struct argp_option options[] = {
    { "key-file", 'k', "FILE", 0, "Read the 32-byte key from FILE (required)", 0 },
    { "cipher", 'c', "CIPHER", 0, "Only chacha20-poly1305, the default", 0 },
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

int main(int argc, char **argv)
{
    /* Prefix diagnostics from error(3) with the bare program name. */
    set_program_name(last_component(argv[0]));

    struct args a = {};
    argp_parse(&argp, argc, argv, 0, nullptr, &a);

    if (sodium_init() < 0)
        error(EXIT_FAILURE, 0, "cannot initialise libsodium");

    unsigned char key[KEY_BYTES];
    if (!key_load(a.key_file, key))
        return EXIT_FAILURE;

    FILE *in = stdin;
    const char *in_name = "-";
    if (a.input != nullptr && strcmp(a.input, "-") != 0) {
        in_name = a.input;
        in = fopen(in_name, "rb");
        if (in == nullptr) {
            sodium_memzero(key, sizeof key);
            error(EXIT_FAILURE, errno, "%s", in_name);
        }
    }

    bool ok = a.command == CMD_ENCRYPT
                  ? stream_encrypt(in, stdout, key)
                  : stream_decrypt(in, stdout, key);
    sodium_memzero(key, sizeof key);

    if (in != stdin)
        fclose(in);
    if (fclose(stdout) != 0 && ok) {
        error(0, errno, "write error");
        ok = false;
    }
    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
