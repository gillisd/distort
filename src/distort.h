/* distort — streaming authenticated encryption on top of libsodium. */
#pragma once

#include <stdio.h>

#include <sodium.h>

constexpr size_t KEY_BYTES = crypto_secretstream_xchacha20poly1305_KEYBYTES;

/* Load a key from path: 32 raw bytes, or 64 hex digits with optional trailing newline. */
[[nodiscard]] bool key_load(const char *path, unsigned char key[KEY_BYTES]);

/* Stream in → out. Diagnostics are printed; returns false on any failure. */
[[nodiscard]] bool stream_encrypt(FILE *in, FILE *out, const unsigned char key[KEY_BYTES]);
[[nodiscard]] bool stream_decrypt(FILE *in, FILE *out, const unsigned char key[KEY_BYTES]);
