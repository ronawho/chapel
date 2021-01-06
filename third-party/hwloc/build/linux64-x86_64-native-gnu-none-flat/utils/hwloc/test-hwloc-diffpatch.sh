#!/bin/sh
#-*-sh-*-

#
# Copyright © 2009-2018 Inria.  All rights reserved.
# Copyright © 2014 Cisco Systems, Inc.  All rights reserved.
# See COPYING in top-level directory.
#

HWLOC_top_srcdir="/tmp/eronagha/chapel/third-party/hwloc/hwloc-src"
HWLOC_top_builddir="/tmp/eronagha/chapel/third-party/hwloc/build/linux64-x86_64-native-gnu-none-flat"
srcdir="$HWLOC_top_srcdir/utils/hwloc"
builddir="$HWLOC_top_builddir/utils/hwloc"
diff="$builddir/hwloc-diff"
patch="$builddir/hwloc-patch"

HWLOC_PLUGINS_PATH=${HWLOC_top_builddir}/hwloc
export HWLOC_PLUGINS_PATH

HWLOC_DEBUG_CHECK=1
export HWLOC_DEBUG_CHECK

if test x0 = x1; then
  # make sure we use default numeric formats
  LANG=C
  LC_ALL=C
  export LANG LC_ALL
fi

: ${TMPDIR=/tmp}
{
  tmp=`
    (umask 077 && mktemp -d "$TMPDIR/fooXXXXXX") 2>/dev/null
  ` &&
  test -n "$tmp" && test -d "$tmp"
} || {
  tmp=$TMPDIR/foo$$-$RANDOM
  (umask 077 && mkdir "$tmp")
} || exit $?

cd "$tmp"
diffoutput="test-hwloc-diffpatch.diff.xml"
output1="test-hwloc-diffpatch.output1"
output2="test-hwloc-diffpatch.output2"

set -e

$diff $srcdir/test-hwloc-diffpatch.input1 \
    $srcdir/test-hwloc-diffpatch.input2 > $diffoutput
cp $srcdir/test-hwloc-diffpatch.input1 .
#cat $diffoutput | $patch $srcdir/test-hwloc-diffpatch.input1 - $output1
cat $diffoutput | $patch refname - $output1
$patch -R $srcdir/test-hwloc-diffpatch.input2 $diffoutput $output2

/usr/bin/diff -u -w $srcdir/test-hwloc-diffpatch.input1 "$output2"
/usr/bin/diff -u -w $srcdir/test-hwloc-diffpatch.input2 "$output1"

cd ..
rm -rf "$tmp"
