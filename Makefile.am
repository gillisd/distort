BUILT_SOURCES =
CLEANFILES =
EXTRA_DIST = man/distort.x m4/gnulib-cache.m4
MOSTLYCLEANFILES =
MOSTLYCLEANDIRS =
noinst_LIBRARIES =
AM_CPPFLAGS = -I$(top_builddir)/lib -I$(top_srcdir)/lib
AM_CFLAGS =

include lib/gnulib.mk

bin_PROGRAMS = distort
distort_SOURCES = src/distort.h src/key.c src/main.c src/stream.c
distort_CFLAGS = $(WARN_CFLAGS) $(SODIUM_CFLAGS)
distort_LDADD = lib/libdistort.a $(SODIUM_LIBS) $(HARD_LOCALE_LIB) $(LIBC32CONV) \
	$(LIBINTL) $(LIBUNISTRING) $(MBRTOWC_LIB) $(SETLOCALE_NULL_LIB)

dist_man1_MANS = man/distort.1
# Regenerated only when its sources change, so tarball builds never need help2man.
man/distort.1: man/distort.x src/main.c configure.ac | distort$(EXEEXT)
	$(AM_V_GEN)$(MKDIR_P) man && \
	$(HELP2MAN) -N -i $(srcdir)/man/distort.x -o $@ ./distort$(EXEEXT)

dist_check_SCRIPTS = tests/roundtrip.sh
TESTS = $(dist_check_SCRIPTS)
