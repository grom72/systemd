#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2023, Intel Corporation
#
#
# Generate the complete calls graph for a given API functions list based on
# the cflow tool.
#

UNSAFE=$1 # '-f' to omit security checks

WD=$(realpath $(dirname "$0"))
SRC=$(realpath $WD/../src/libudev)

API=$WD/api.txt
if [ ! -f "$API" ]; then
	echo "$API is missing"
	exit 1
fi

EXTRA_ENTRY_POINTS=$WD/extra_entry_points.txt
if [ ! -f "$EXTRA_ENTRY_POINTS" ]; then
	echo "$EXTRA_ENTRY_POINTS is missing"
	exit 1
fi

STARTS=
for start in `cat $API $EXTRA_ENTRY_POINTS`; do
	STARTS="$STARTS --start $start"
done

cd $SRC

pwd

SOURCES="./libudev*.c ./libudev*.h ../shared/udev*.c ../shared/udev*.h ../basic/*.h  ../basic/*.c "

ABORT=yes
UNCOMMITED=$(git status -s $SOURCES)

if [ "z$UNSAFE" == "z-f" ]; then
	ABORT=no
elif [ -z "$UNCOMMITED" ]; then
	ABORT=no
fi

if [ $ABORT == "yes" ]; then
	echo "The repository has uncommitted changes. Can't continue without overwriting them."
	echo "Call '$0 -f' to continue regardless."
	exit 1
fi

# Note: cflow cannot process correctly a for-loop if the initialization step of
# the loop declares a variable. It doesn't care if a variable is not defined.
# So, removing the initialization step from all the for-loops works around
# the problem.
sed -i 's/for ([^;]\+;/for (;/' $SOURCES

# Note: --symbol list has been defined based on cflow manual
# https://www.gnu.org/software/cflow/manual/cflow.html
# Section: 6.3 GCC Initialization

# Note: The preprocess argument and used defines and includes should mirror
# the compile command as it is used in the build system. Please update if
# necessary.
#
# To build a new preprocess command:
# 1. run `make libpmemobj` command in the PMDK/src folder
# 2. take one of the `cc ...` lines and:
# 2.1 remove all -W, -o, -MD, and -c parameters and any file name that is included in the command line
# 2.2 take -D parameters and add them directly to the cflow command
# 2.3 take -I parameters and add them directly to the cflow command
# 2.4 adjust -I parameters to use absolute paths (e.g. by using the $SRC prefix)
# 2.5 update the --preprocess argument with the remaining part of your initial compile command.
# Repeat the above steps with 'libpmem' instead of 'libpmemobj'.
# You do not need to add anything twice.

echo "Code analysis may take more than 5 minutes. Go get yourself a coffee."

echo "Start"

cflow -o $WD/cflow.txt \
	--symbol __inline:=inline \
	--symbol __attribute__:wrapper \
	--symbol __asm__:wrapper \
	--symbol __nonnull:wrapper \
	--symbol __wur:wrapper \
	--symbol __extension__:qualifier \
	--symbol U:qualifier \
	--symbol assert:wrapper \
	-I../../src/libudev -I../../src/libudev -I../../src/basic \
	-I../../src/basic -I../../src/fundamental -I../../src/fundamental \
	-I../../src/systemd -I../../src/systemd -I. -I.. \
	-I../../src/libsystemd/sd-bus -I../../src/libsystemd/sd-device \
	-I../../src/libsystemd/sd-event -I../../src/libsystemd/sd-hwdb \
	-I../../src/libsystemd/sd-id128 -I../../src/libsystemd/sd-journal \
	-I../../src/libsystemd/sd-netlink -I../../src/libsystemd/sd-network \
	-I../../src/libsystemd/sd-resolve -I../../src/shared -I../../src/shared \
	-I../../build \
	-D_FILE_OFFSET_BITS=64 \
	--preprocess='gcc -E  -fdiagnostics-color=always -std=gnu11 -g -fdiagnostics-show-option -fno-common -fstack-protector -fstack-protector-strong --param=ssp-buffer-size=4 -fPIC -fno-strict-aliasing -fvisibility=hidden -fno-omit-frame-pointer -include config.h -fvisibility=default' \
	$STARTS $SOURCES 2> $WD/cflow.err

echo "Done."

# Restore the state of the files that have been modified to work around
# the cflow's for-loop problem. Please see the note above for details.
if [ ! "z$UNSAFE" == "z-f" ]; then
	git restore $SOURCES
else
	echo "Note: $0 probably modified the source code."
fi