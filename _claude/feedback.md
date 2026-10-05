Two edge cases are also right. An input that's an exact multiple of 64 KiB puts FINAL on the last full chunk, so there's no empty trailing chunk. An empty input produces a valid 0-byte FINAL chunk, and it round-trips.

Nits, most important first:

-c/--cipher is dead weight. It accepts one value and nothing is recorded in the format, so any future cipher change will come through the version byte anyway. I'd remove it.
Low-rate streams stall. fread blocks until it has a full 64 KiB, and at_eof then blocks on the next byte. That's fine for files and archives, but something like tail -f | distort encrypt holds output for up to a chunk. Worth one README line saying it's not for live streams.
Plaintext copies survive in stdio buffers. wipe() clears pt, but plaintext also sits in in's stdio buffer (encrypt) and stdout's buffer (decrypt). Either accept that and drop the comment's implied guarantee, or read and write through read(2)/write(2).
The README still has the earlier typos: "xchaha20", .tar.zst for tar cz output, and the missing cp in aws s3 cp. The examples also need set -o pipefail.

Updated verdict: for a single-key pipeline, distort now has everything I said age had over it, except age's years of use and outside review. That, the plugin ecosystem, and seekable decryption are what's left in age's favor.
