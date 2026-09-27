#!/bin/sh
# Smoke test: round trips through distort, and a wrong key is rejected.
set -e
trap 'rm -f rt.key rt.in rt.enc rt.out' EXIT
head -c 32 /dev/urandom > rt.key
for n in 0 1 65536 200000; do
  head -c $n /dev/urandom > rt.in
  ./distort encrypt -k rt.key rt.in > rt.enc
  ./distort decrypt -k rt.key < rt.enc > rt.out
  cmp rt.in rt.out
done
head -c 32 /dev/urandom > rt.key
! ./distort decrypt -k rt.key rt.enc > /dev/null 2>&1
