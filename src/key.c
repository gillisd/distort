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

    unsigned char buf[KEY_BYTES + 1]; /* one byte more than a valid file */
    size_t n = fread(buf, 1, sizeof buf, f);
    bool ok = !ferror(f);
    int saved = errno;
    fclose(f);
    if (!ok) {
        error(0, saved, "%s", path);
        sodium_memzero(buf, sizeof buf);
        return false;
    }

    ok = n == KEY_BYTES;
    if (ok)
        memcpy(key, buf, KEY_BYTES);
    sodium_memzero(buf, sizeof buf);
    if (!ok)
        error(0, 0, "%s: invalid key: expected 32 bytes", path);
    return ok;
}
