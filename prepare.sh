#!/bin/bash
set -e

VERSION=$(echo ${1} | sed -ne "/^[0-9]\+\.[0-9]\+\.[0-9]\+$/p")
DEST_DIR=${2:-libvalhalla}
REPOS="midgard baldr sif meili skadi mjolnir loki odin thor tyr tools"
DIRS="valhalla src test proto scripts m4 date_time lua locales"
source ./target
if [ -z ${VERSION} ]; then
	echo "$0 major.minor.patch"
	exit 1
fi

rm -rf ${DEST_DIR}
mkdir ${DEST_DIR}
pushd ${DEST_DIR}

#the version of the package
mkdir valhalla
cat > valhalla/valhalla.h << EOF
#ifndef __VALHALLA_VERSION_H__
#define __VALHALLA_VERSION_H__

#define VALHALLA_VERSION_MAJOR $(echo ${VERSION} | awk -F. '{print $1}')
#define VALHALLA_VERSION_MINOR $(echo ${VERSION} | awk -F. '{print $2}')
#define VALHALLA_VERSION_PATCH $(echo ${VERSION} | awk -F. '{print $3}')

#endif
EOF

#for pkg-config
cat > libvalhalla.pc.in << "EOF"
prefix=@prefix@
exec_prefix=@exec_prefix@
libdir=@libdir@
includedir=@includedir@

Name: libvalhalla
Description: valhalla c++ library
Version: @VERSION@
Libs: -L${libdir} -lvalhalla
Cflags: -I${includedir}
EOF

#generate configure script with this script
cat > autogen.sh << EOF
#!/bin/bash
aclocal -I m4
autoreconf -fi --warning=no-portability
EOF
chmod 755 autogen.sh

#copy in the good stuff
for r in ${REPOS}; do echo ${r}; done |	xargs -i -n 1 -P $(nproc) git clone --quiet --branch ${VERSION} --depth 1 --recursive  https://github.com/valhalla/{}.git &
wait
for r in ${REPOS}; do
	for d in ${DIRS}; do
		if [ -e ${r}/${d} ]; then
			mkdir -p ${d}
			cp -rpL ${r}/${d}/* ${d}
		fi
	done
done

#some other autotools junk
cp -rp $(echo ${REPOS} | awk '{print $1}')/NEWS .
cp -rp $(echo ${REPOS} | awk '{print $1}')/AUTHORS .
cp -rp $(echo ${REPOS} | awk '{print $1}')/COPYING .
cat > README << "EOF"
See https://github.com/valhalla for more info about the various parts of the system.
EOF
curl 'https://raw.githubusercontent.com/valhalla/valhalla-docs/master/release-notes.md' 2>/dev/null > ChangeLog

cat > Makefile.am << EOF
ACLOCAL_AMFLAGS = -Im4
AM_LDFLAGS = $(grep -rE "^AM_LDFLAGS" */Makefile.am | sed -e "s/.*=\s*//g" -e "s/ /\n/g" -e "s/@PTHREAD_[A-Z]\+@//g" | sort | uniq | tr '\n' ' ')
AM_CPPFLAGS = $(grep -rE "^AM_CPPFLAGS" */Makefile.am | sed -e "s/.*=\s*//g" -e "s/ /\n/g" -e "s/@PTHREAD_[A-Z]\+@//g" | sort | uniq | tr '\n' ' ')
AM_CXXFLAGS = $(grep -rE "^AM_CXXFLAGS" */Makefile.am | sed -e "s/.*=\s*//g" -e "s/ /\n/g" -e "s/@PTHREAD_[A-Z]\+@//g" | sort | uniq | tr '\n' ' ')
LIBTOOL_DEPS = @LIBTOOL_DEPS@
libtool: \$(LIBTOOL_DEPS)
	\$(SHELL) ./config.status libtool

# things for versioning
pkgconfig_DATA = libvalhalla.pc

# conditional test coverage
if ENABLE_COVERAGE
.PHONY: clean-coverage
clean-coverage:
	-find -name '*.gcda' -exec rm -rf {} \\;
	-\$(LCOV) --directory \$(top_builddir) -z
	-rm -rf coverage.info coverage/

.PHONY: coverage-report
coverage-report: clean-coverage
	-\$(MAKE) \$(AM_MAKEFLAGS) -k check
	\$(MAKE) \$(AM_MAKEFLAGS) coverage/index.html

coverage.info:
	\$(LCOV) --directory \$(top_builddir) --base-directory \$(top_builddir) --no-external --capture --output-file \$@ --no-checksum --compat-libtool

coverage/index.html: coverage.info
	\$(GENHTML) --prefix \$(top_builddir) --output-directory \$(@D) --title "Test Coverage" --legend --show-details $<


.PHONY: clean-gcno
clean-gcno:
	-find -name '*.gcno' -exec rm -rf {} \\;

clean-local: clean-coverage clean-gcno clean-genfiles
else
clean-local: clean-genfiles
endif

clean-genfiles:
	-rm -rf genfiles

EOF


#extra targets date_time, lua, locales
extras=
for r in ${REPOS}; do
	for l in $(grep -nE "^src.*:|^genfiles.*:" ${r}/Makefile.am | grep -vF proto | sed -e "s/:.*//g"); do
		target ${l} ${r}/Makefile.am >> Makefile.am
		extras="${extras} $(target ${l} ${r}/Makefile.am | head -n 1 | sed -e "s/:.*//g")"
	done
done

#proto targets
cat >> Makefile.am << EOF

PROTO_FILES = $(find proto/ -type f | tr '\n' ' ')
src/proto/%.pb.cc: proto/%.proto
	@echo " PROTOC $<"; mkdir -p src/proto valhalla/proto; @PROTOC_BIN@ -Iproto --cpp_out=valhalla/proto $< && mv valhalla/proto/\$(@F) src/proto

EOF

#add built stuff to sources, no dist and clean
cat >> Makefile.am << EOF
BUILT_SOURCES = \$(patsubst %.proto,src/%.pb.cc,\$(PROTO_FILES)) ${extras}
nodist_libvalhalla_la_SOURCES = \$(patsubst %.proto,src/%.pb.cc,\$(PROTO_FILES)) ${extras}
CLEANFILES = \$(patsubst %.proto,valhalla/%.pb.h,\$(PROTO_FILES)) \$(patsubst %.proto,src/%.pb.cc,\$(PROTO_FILES))

EOF

#lib and headers
#TODO: unclobber generated valhalla.h with midgards
echo "lib_LTLIBRARIES = libvalhalla.la
nobase_include_HEADERS = \\" >> Makefile.am
for r in ${REPOS}; do
	for l in $(grep -nE "^nobase_include_HEADERS" ${r}/Makefile.am | sed -e "s/:.*//g"); do
		target ${l} ${r}/Makefile.am | sed -e "s/[[:space:]\\\\]*$//g" -e "s/^\s*//g" -e "s/^nobase_include_HEADERS[ =]*//g" -e '/^\s*$/d'
	done
done | tr '\n' ' ' | sed -e "s/\s*$//g" -e "s/\s\+/ \\\\\n/g" | sed -e "s/^/\t/g" >> Makefile.am

#sources
echo "
libvalhalla_la_SOURCES = \\" >> Makefile.am
for r in ${REPOS}; do
	for l in $(grep -nE "^libvalhalla_${r}_la_SOURCES" ${r}/Makefile.am | sed -e "s/:.*//g"); do
		target ${l} ${r}/Makefile.am | sed -e "s/[[:space:]\\\\]*$//g" -e "s/^\s*//g" -e "s/^libvalhalla_${r}_la_SOURCES[ =]*//g" -e '/^\s*$/d'
	done
done | tr '\n' ' ' | sed -e "s/\s*$//g" -e "s/\s\+/ \\\\\n/g" | sed -e "s/^/\t/g" >> Makefile.am
echo >> Makefile.am

#flags
sed -e "s/^libvalhalla_.*_la_CPPFLAGS\s*=\s*//;tx;d;:x" */Makefile.am | tr ' ' '\n' | grep -vF VALHALLA | sort | uniq | tr '\n' ' ' | sed -e "s/^/libvalhalla_la_CPPFLAGS = /g" >> Makefile.am
echo >> Makefile.am

#libs to link
sed -e "s/^libvalhalla_.*_la_LIBADD\s*=\s*//;tx;d;:x" */Makefile.am | tr ' ' '\n' | grep -vF VALHALLA | sort | uniq | tr '\n' ' ' | sed -e "s/^/libvalhalla_la_LIBADD = /g" >> Makefile.am
echo >> Makefile.am
echo >> Makefile.am

#executable targets
echo "bin_PROGRAMS = \\" >> Makefile.am
bins=$(wc -l < Makefile.am)
for r in ${REPOS}; do
	for l in $(grep -nE "^bin_PROGRAMS" ${r}/Makefile.am | sed -e "s/:.*//g"); do
		target ${l} ${r}/Makefile.am | sed -e "s/[[:space:]\\\\]*$//g" -e "s/^\s*//g" -e "s/^bin_PROGRAMS[ =]*//g" -e '/^\s*$/d'
        done
done | tr '\n' ' ' | sed -e "s/\s*$//g" -e "s/\s\+/ \\\\\n/g" | sed -e "s/^/\t/g" >> Makefile.am
echo >> Makefile.am
for e in $(target ${bins} Makefile.am | grep -vF bin_PROGRAMS | sed -e "s/[[:space:]\\]*//g"); do
	grep -hE "^${e}_[A-Z]" */Makefile.am | sed -e "s/libvalhalla_[a-z]\+\.la//g" -e "s/ [^[:space:]]\+VALHALLA_DEPS[^[:space:]]\+//g" -e "s/\(.*LDADD.*\)/\1 libvalhalla.la/g" >> Makefile.am
done
echo >> Makefile.am

#script targets
echo "bin_SCRIPTS = \\" >> Makefile.am
scripts=$(wc -l < Makefile.am)
for r in ${REPOS}; do
        for l in $(grep -nE "^bin_SCRIPTS" ${r}/Makefile.am | sed -e "s/:.*//g"); do
                target ${l} ${r}/Makefile.am | sed -e "s/[[:space:]\\\\]*$//g" -e "s/^\s*//g" -e "s/^bin_SCRIPTS[ =]*//g" -e '/^\s*$/d'
        done
done | tr '\n' ' ' | sed -e "s/\s*$//g" -e "s/\s\+/ \\\\\n/g" | sed -e "s/^/\t/g" >> Makefile.am
echo >> Makefile.am

#test targets
echo "TESTS_ENVIRONMENT = LOCPATH=locales" >> Makefile.am
echo "check_PROGRAMS = \\" >> Makefile.am
checks=$(wc -l < Makefile.am)
for r in ${REPOS}; do
	for l in $(grep -nE "^check_PROGRAMS" ${r}/Makefile.am | sed -e "s/:.*//g"); do
		target ${l} ${r}/Makefile.am | sed -e "s/[[:space:]\\\\]*$//g" -e "s/^\s*//g" -e "s/^check_PROGRAMS[ =]*//g" -e '/^\s*$/d'
	done
done | tr '\n' ' ' | sed -e "s/\s*$//g" -e "s/\s\+/ \\\\\n/g" | sed -e "s/^/\t/g" >> Makefile.am
echo >> Makefile.am
for t in $(target ${checks} Makefile.am | grep -vF check_PROGRAMS | sed -e "s/[[:space:]\\]*//g" -e "s@/@_@g"); do
	grep -hE "^${t}_[A-Z]" */Makefile.am | sed -e "s/libvalhalla_[a-z]\+\.la//g" -e "s/ [^[:space:]]\+VALHALLA_DEPS[^[:space:]]\+//g" -e "s/\(.*LDADD.*\)/\1 libvalhalla.la/g" >> Makefile.am
done
echo >> Makefile.am

cat >> Makefile.am << "EOF"
TESTS = $(check_PROGRAMS)
TEST_EXTENSIONS = .sh
SH_LOG_COMPILER = sh

test: check
EOF

#cleanup
rm -rf ${REPOS}

#TODO: create this from the subprojects' configure.ac's
cat > configure.ac << EOF
AC_INIT([valhalla],
	[${VERSION}],
	[https://github.com/valhalla/packaging/issues],
	[valhalla-${VERSION}],
	[https://github.com/valhalla/packaging])
AC_CONFIG_AUX_DIR([.])
AM_INIT_AUTOMAKE([subdir-objects parallel-tests])
LT_INIT
AC_SUBST([LIBTOOL_DEPS])

AM_SILENT_RULES([yes])
AC_CONFIG_HEADERS([valhalla/config.h])
AC_CONFIG_MACRO_DIR([m4])

# set pkgconfigdir, allow override
AC_ARG_WITH([pkgconfigdir],
            AS_HELP_STRING([--with-pkgconfigdir=PATH], [Path to the pkgconfig directory [[LIBDIR/pkgconfig]]]),
            [pkgconfigdir="\$withval"],
            [pkgconfigdir='\${libdir}/pkgconfig'])
AC_SUBST([pkgconfigdir])

AC_PROG_CXX
AC_PROG_INSTALL
AC_PROG_MAKE_SET

AC_HEADER_STDC
AC_LANG_CPLUSPLUS

# require c++11
AX_CXX_COMPILE_STDCXX_11([noext],[mandatory])

# check for protocol buffers compiler and libraries
REQUIRE_PROTOC

# check for boost and make sure we have the program options library
AX_BOOST_BASE([1.54], , [AC_MSG_ERROR([cannot find Boost libraries, which are are required for building valhalla. Please install libboost-all-dev.])])
AX_BOOST_PROGRAM_OPTIONS
AX_BOOST_SYSTEM
AX_BOOST_THREAD
AX_BOOST_FILESYSTEM
AX_BOOST_REGEX
AX_BOOST_DATE_TIME

# check for Lua libraries and headers
AX_PROG_LUA([5.2],[],[
    AX_LUA_HEADERS([
        AX_LUA_LIBS([
        ],[AC_MSG_ERROR([Cannot find Lua libs.   Please install lua5.2 liblua5.2-dev])])
    ],[AC_MSG_ERROR([Cannot find Lua includes.  Please install lua5.2 liblua5.2-dev])])
],[AC_MSG_ERROR([Cannot find Lua interpreter.   Please install lua5.2 liblua5.2-dev])])

AX_LIB_SQLITE3(3.0.0)

if test "x\$SQLITE3_VERSION" = "x"; then
  AC_MSG_ERROR(['libsqlite-dev' version >= 3.0.0 is required.  Please install libsqlite-dev.])
fi

# Check for Geos library
AX_LIB_GEOS(3.0.0)
if test "x\$GEOS_VERSION" = "x"
then
  AC_MSG_ERROR(['geos' version >= 3.0.0 is required.  Please install geos.]);
fi

# spatialite needed for admin info
PKG_CHECK_MODULES([LIBSPATIALITE], [spatialite >= 3.0.0], , AC_MSG_ERROR(['libspatialite-dev' version >= 3.0.0 is required.  Please install libspatialite-dev.]))

# check pkg-config packaged packages.
PKG_CHECK_MODULES([DEPS], [protobuf >= 2.4.0 libprime_server >= 0.3.4 libcurl >= 7.35.0])

# optionally enable coverage information
CHECK_COVERAGE

AC_CONFIG_FILES([Makefile libvalhalla.pc])

# Debian resets this to no, but this break both Spot and the libtool
# test suite itself.  Instead of requiring developer to install a
# non-patched version of Libtool on any Debian they use, we just
# cancel the effect of Debian's patch here.
# see: http://git.lrde.epita.fr/?p=spot.git;a=commitdiff;h=0e74b76521341f670f6b76f8ef24a6dcf6e3813b
link_all_deplibs=yes
link_all_deplibs_CXX=yes

AC_OUTPUT
EOF

popd
