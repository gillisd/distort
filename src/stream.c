/*
 * Wire format:
 *
 *   preamble  "DISTORT" | format version (0x01)               8 bytes
 *   header    crypto_secretstream_xchacha20poly1305 header   24 bytes
 *   chunks    crypto_secretstream_xchacha20poly1305_push of up to CHUNK
 *             plaintext bytes each; every chunk is full-sized except
 *             possibly the last, which alone carries TAG_FINAL.
 *
 * The preamble is bound to every chunk as additional data.
 */
#include <config.h>

#include <errno.h>
#include <error.h>
#include <string.h>

#include "distort.h"

constexpr unsigned char FORMAT_VERSION = 1;
constexpr unsigned char PREAMBLE[] = { 'D', 'I', 'S', 'T', 'O', 'R', 'T', FORMAT_VERSION };
constexpr size_t MAGIC_BYTES = sizeof PREAMBLE - 1;
constexpr size_t HEADER_BYTES = crypto_secretstream_xchacha20poly1305_HEADERBYTES;
constexpr size_t ABYTES = crypto_secretstream_xchacha20poly1305_ABYTES;
constexpr size_t CHUNK = 64 * 1024;
constexpr unsigned char TAG_MESSAGE = crypto_secretstream_xchacha20poly1305_TAG_MESSAGE;
constexpr unsigned char TAG_FINAL = crypto_secretstream_xchacha20poly1305_TAG_FINAL;

static unsigned char pt[CHUNK];
static unsigned char ct[CHUNK + ABYTES];

static bool write_all(FILE *out, const void *buf, size_t n)
{
    if (fwrite(buf, 1, n, out) == n)
        return true;
    error(0, errno, "write error");
    return false;
}

static bool read_failed(FILE *in)
{
    if (!ferror(in))
        return false;
    error(0, errno, "read error");
    return true;
}

/* True when in has no more bytes; peeks without consuming. */
static bool at_eof(FILE *in)
{
    int c = getc(in);
    if (c == EOF)
        return true;
    ungetc(c, in);
    return false;
}

static void wipe(crypto_secretstream_xchacha20poly1305_state *st)
{
    sodium_memzero(st, sizeof *st);
    sodium_memzero(pt, sizeof pt);
}

bool stream_encrypt(FILE *in, FILE *out, const unsigned char key[KEY_BYTES])
{
    crypto_secretstream_xchacha20poly1305_state st;
    unsigned char header[HEADER_BYTES];
    bool ok = false;

    crypto_secretstream_xchacha20poly1305_init_push(&st, header, key);
    for (bool final = false, first = true; !final; first = false) {
        size_t n = fread(pt, 1, CHUNK, in);
        if (read_failed(in))
            goto done;
        /* Emit nothing until the input has proven readable. */
        if (first && (!write_all(out, PREAMBLE, sizeof PREAMBLE) ||
                      !write_all(out, header, sizeof header)))
            goto done;
        final = n < CHUNK || at_eof(in);
        if (read_failed(in))
            goto done;

        unsigned long long clen;
        crypto_secretstream_xchacha20poly1305_push(&st, ct, &clen, pt, n, PREAMBLE, sizeof PREAMBLE,
                                                   final ? TAG_FINAL : TAG_MESSAGE);
        if (!write_all(out, ct, (size_t)clen))
            goto done;
    }
    ok = true;
done:
    wipe(&st);
    return ok;
}

bool stream_decrypt(FILE *in, FILE *out, const unsigned char key[KEY_BYTES])
{
    unsigned char preamble[sizeof PREAMBLE];
    crypto_secretstream_xchacha20poly1305_state st = {};
    unsigned char header[HEADER_BYTES];
    bool ok = false;

    size_t n = fread(preamble, 1, sizeof preamble, in);
    if (read_failed(in))
        return false;
    if (n < MAGIC_BYTES || memcmp(preamble, PREAMBLE, MAGIC_BYTES) != 0) {
        error(0, 0, "input is not a distort stream");
        return false;
    }
    if (n < sizeof preamble) {
        error(0, 0, "unexpected end of input: stream is truncated");
        return false;
    }
    if (preamble[MAGIC_BYTES] != FORMAT_VERSION) {
        error(0, 0, "unsupported stream format version %u", preamble[MAGIC_BYTES]);
        return false;
    }
    if (fread(header, 1, sizeof header, in) != sizeof header) {
        if (!read_failed(in))
            error(0, 0, "unexpected end of input: stream is truncated");
        return false;
    }
    if (crypto_secretstream_xchacha20poly1305_init_pull(&st, header, key) != 0) {
        error(0, 0, "invalid stream header");
        goto done;
    }

    for (bool final = false; !final;) {
        n = fread(ct, 1, sizeof ct, in);
        if (read_failed(in))
            goto done;
        if (n < ABYTES) {
            error(0, 0, "unexpected end of input: stream is truncated");
            goto done;
        }
        final = n < sizeof ct || at_eof(in);
        if (read_failed(in))
            goto done;

        unsigned long long plen;
        unsigned char tag;
        if (crypto_secretstream_xchacha20poly1305_pull(&st, pt, &plen, &tag, ct, n, PREAMBLE,
                                                       sizeof PREAMBLE) != 0) {
            error(0, 0, "authentication failed: wrong key, or data is corrupt or truncated");
            goto done;
        }
        if ((tag == TAG_FINAL) != final) {
            error(0, 0, final ? "unexpected end of input: stream is truncated"
                              : "unexpected data after end of stream");
            goto done;
        }
        if (!write_all(out, pt, (size_t)plen))
            goto done;
    }
    ok = true;
done:
    wipe(&st);
    return ok;
}
