[NAME]
distort \- encrypt or decrypt a stream with authenticated encryption

[>DESCRIPTION]
.PP
The stream is sealed with chacha20\-poly1305 (libsodium's secretstream)
in 64 KiB chunks, so memory use is constant.
Every chunk is authenticated.
.B decrypt
writes each chunk only after verifying it, and fails if the stream is
reordered, truncated, extended, or was sealed with another key.
Output written before a failure is authentic but incomplete;
trust the data only if the exit status is 0.

[FORMAT]
An 8\-byte preamble (\(lqDISTORT\(rq and the format byte 1),
libsodium's 24\-byte secretstream header, then the chunks,
each sealed with the preamble as additional data;
only the last carries the final tag.

[=EXAMPLES]
.nf
tar cz dir | distort encrypt \-k key.key > dir.tgz.enc
distort decrypt \-k key.key < dir.tgz.enc | tar xz
distort encrypt \-k key.key notes.txt > notes.txt.enc
.fi
.PP
Make a key:
.PP
.nf
head \-c 32 /dev/urandom > key.key
.fi

[EXIT STATUS]
0 on success, 1 on failure or a damaged stream, 64 on a usage error.

[SEE ALSO]
.BR age (1),
.BR gpg (1),
https://doc.libsodium.org/secret\-key_cryptography/secretstream
