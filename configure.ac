AC_INIT([distort], [0.1.0], [david@flipmine.com])
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

AC_ARG_ENABLE([gcc-warnings],
  [AS_HELP_STRING([--enable-gcc-warnings],
    [turn on lots of compiler warnings (for developers)])],
  [AS_CASE([$enableval], [yes|no], [],
     [AC_MSG_ERROR([bad value $enableval for gcc-warnings option])])
   gl_gcc_warnings=$enableval],
  [gl_gcc_warnings=no
   test -e "$srcdir/.git" && gl_gcc_warnings=yes])
AS_IF([test "$gl_gcc_warnings" = yes], [
  gl_MANYWARN_ALL_GCC([ws])
  for w in $ws; do
    gl_WARN_ADD([$w])
  done
])

AC_ARG_ENABLE([static-binary],
  [AS_HELP_STRING([--enable-static-binary],
    [build a fully static binary (macOS: libsodium only)])],
  [], [enable_static_binary=no])

PKG_PROG_PKG_CONFIG
AS_IF([test "$enable_static_binary" = yes],
  [PKG_CHECK_MODULES_STATIC([SODIUM], [libsodium])
   AS_CASE([$host_os],
     [darwin*],
       [dnl Darwin has no static C library; link libsodium's archive instead.
        PKG_CHECK_VAR([sodium_libdir], [libsodium], [libdir])
        SODIUM_LIBS="$sodium_libdir/libsodium.a"],
     [LDFLAGS="$LDFLAGS -static"])],
  [PKG_CHECK_MODULES([SODIUM], [libsodium])])

AM_MISSING_PROG([HELP2MAN], [help2man])

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
