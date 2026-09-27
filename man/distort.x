[NAME]
distort \- encrypt or decrypt a stream with authenticated encryption

[>DESCRIPTION]
.PP
Every chunk is authenticated.
.B decrypt
writes each chunk only after verifying it, and fails if the stream is
reordered, truncated, extended, or was sealed with another key.
Output written before a failure is authentic but incomplete;
trust the data only if the exit status is 0.

[FORMAT]
An 8\-byte preamble (\(lqDISTORT\(rq and the format byte 1), the 24\-byte
.B crypto_secretstream_xchacha20poly1305
header, then chunks sealed with
.BR crypto_secretstream_xchacha20poly1305_push ;
only the last carries the final tag.
The preamble is authenticated with every chunk.

[EXAMPLES]
.nf
cat stream.bin | distort encrypt \-\-key\-file key.key > stream.bin.enc
cat stream.bin.enc | distort decrypt \-\-key\-file key.key > stream.bin
distort encrypt \-\-key\-file=key.key bigfile.bin > bigfile.bin.enc
tar cz *.txt | distort encrypt \-k key.key | aws s3 cp \- s3://bucket/txt.tgz.enc
.fi

[BUILDING]
For a self\-contained binary, run
.BR "./configure \-\-enable\-static\-binary" :
fully static on Linux; on macOS, libsodium is linked in statically.

[SEE ALSO]
.BR age (1),
.BR gpg (1),
https://doc.libsodium.org/secret\-key_cryptography/secretstream
