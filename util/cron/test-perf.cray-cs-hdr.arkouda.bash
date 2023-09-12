#!/usr/bin/env bash
#
# Run arkouda testing on a cray-cs with HDR IB

CWD=$(cd $(dirname $0) ; pwd)

export CHPL_TEST_PERF_CONFIG_NAME='16-node-cs-hdr'
export CHPL_NIGHTLY_TEST_CONFIG_NAME="perf.cray-cs-hdr.arkouda"

# setup arkouda
#source $CWD/common-arkouda.bash
#export ARKOUDA_NUMLOCALES=16

module list

# setup for apollo
source $CWD/common-perf.bash
source $CWD/common-hpe-apollo.bash
unset CHPL_TEST_LAUNCHCMD
export CHPL_LAUNCHER=pbs-gasnetrun_ibv
export CHPL_LAUNCHER_CORES_PER_LOCALE=144
export CHPL_LAUNCHER_QUEUE=f2401THP
export CHPL_TARGET_CPU=none

module list

export GASNET_PHYSMEM_MAX="9/10"
nightly_args="${nightly_args} -no-buildcheck"

$CWD/nightly -cron -hellos ${nightly_args}
