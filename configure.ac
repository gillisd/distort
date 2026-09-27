AC_INIT([distort], [1.0.0], [david@flipmine.com])
AC_CONFIG_SRCDIR([src/main.c])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([foreign subdir-objects -Wall])
AM_SILENT_RULES([yes])

AC_CANONICAL_HOST
AC_PROG_CC
gl_EARLY
dnl gnulib's C23 probe also checks the C library, which on some systems
dnl (musl) lags the compiler; distort needs only the compiler's C23.
AS_IF([test "x$ac_cv_prog_cc_c23" = xno],
  [gl_COMPILER_OPTION_IF([-std=gnu23], [CC="$CC -std=gnu23"])])
AM_PROG_AR
AC_PROG_RANLIB
gl_INIT

dnl As in other GNU packages, builds from a source checkout (which has
dnl bootstrap.conf) turn on nearly every compiler warning; release builds
dnl use the compiler's defaults, so a newer compiler cannot make them noisy.
AS_IF([test -f "$srcdir/bootstrap.conf"], [
  gl_MANYWARN_ALL_GCC([ws])
  for w in $ws; do
    gl_WARN_ADD([$w])
  done
])

dnl libsodium, found through pkg-config when available.
AC_ARG_ENABLE([static-binary],
  [AS_HELP_STRING([--enable-static-binary],
    [build a fully static binary (macOS: libsodium only)])],
  [], [enable_static_binary=no])

PKG_PROG_PKG_CONFIG
AS_IF([test "$enable_static_binary" = yes],
  [PKG_CHECK_MODULES_STATIC([SODIUM], [libsodium], [], [SODIUM_LIBS=-lsodium])],
  [PKG_CHECK_MODULES([SODIUM], [libsodium], [], [SODIUM_LIBS=-lsodium])])

AS_IF([test "$enable_static_binary" = yes],
  [AS_CASE([$host_os],
    [darwin*],
      [dnl Darwin has no static C library; link libsodium's archive instead.
       sodium_libdir=`$PKG_CONFIG --variable=libdir libsodium 2>/dev/null`
       sodium_archive=
       for d in $sodium_libdir /opt/homebrew/lib /usr/local/lib /opt/local/lib; do
         AS_IF([test -f "$d/libsodium.a"], [sodium_archive=$d/libsodium.a; break])
       done
       AS_IF([test -z "$sodium_archive"],
         [AC_MSG_ERROR([--enable-static-binary needs libsodium.a, which was not found])])
       SODIUM_LIBS=`AS_ECHO([" $SODIUM_LIBS "]) | sed "s| -lsodium | $sodium_archive |"`],
    [LDFLAGS="$LDFLAGS -static"])])

save_CFLAGS=$CFLAGS save_LIBS=$LIBS
CFLAGS="$CFLAGS $SODIUM_CFLAGS" LIBS="$SODIUM_LIBS $LIBS"
AC_CACHE_CHECK([for libsodium], [distort_cv_libsodium],
  [AC_LINK_IFELSE(
    [AC_LANG_PROGRAM([[#include <sodium.h>]],
      [[return sodium_init () < 0
               || crypto_secretstream_xchacha20poly1305_KEYBYTES != 32;]])],
    [distort_cv_libsodium=yes], [distort_cv_libsodium=no])])
CFLAGS=$save_CFLAGS LIBS=$save_LIBS
AS_IF([test "$distort_cv_libsodium" != yes],
  [AS_IF([test "$enable_static_binary" = yes],
    [AC_MSG_ERROR([cannot link libsodium statically; install its static library (on Alpine: libsodium-static, on Fedora: libsodium-static and glibc-static)])],
    [AC_MSG_ERROR([libsodium not found; install it (e.g. libsodium-dev, libsodium-devel or 'brew install libsodium')])])])

AM_MISSING_PROG([HELP2MAN], [help2man])

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
