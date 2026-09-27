#include <config.h>

#include <errno.h>
#include <error.h>
#include <string.h>

#include "distort.h"

bool key_load(const char *path, unsigned char key[KEY_BYTES])
{
    FILE *f = fopen(path, "rb");
    if (f == nullptr) {
        error(0, errno, "%s", path);
        return false;
    }
    setvbuf(f, nullptr, _IONBF, 0); /* keep no copy of the key in a stdio buffer */

    unsigned char buf[2 * KEY_BYTES + 3]; /* one byte more than any valid file */
    size_t n = fread(buf, 1, sizeof buf, f);
    bool ok = !ferror(f);
    int saved = errno;
    fclose(f);
    if (!ok) {
        error(0, saved, "%s", path);
        sodium_memzero(buf, sizeof buf);
        return false;
    }

    if (n == KEY_BYTES) {
        memcpy(key, buf, KEY_BYTES);
    } else {
        size_t len = n;
        if (len > 0 && buf[len - 1] == '\n')
            len -= len > 1 && buf[len - 2] == '\r' ? 2 : 1;
        ok = len == 2 * KEY_BYTES &&
             sodium_hex2bin(key, KEY_BYTES, (const char *)buf, len, nullptr, nullptr, nullptr) == 0;
    }
    sodium_memzero(buf, sizeof buf);
    if (!ok)
        error(0, 0, "%s: invalid key: expected 32 raw bytes or 64 hex digits", path);
    return ok;
}
