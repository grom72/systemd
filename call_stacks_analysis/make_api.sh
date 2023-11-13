#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2023, Intel Corporation
#
#
# Generate a list of all libpmem and libpmemobj public API functions.
#

WD=$(realpath $(dirname $0))
SRC=$(realpath $WD/../src)

LINK_FILES="$SRC/libudev/libudev.sym"

for link in $LINK_FILES; do
	if [ ! -f $link ]; then
		echo "$link is missing"
		exit 1
	fi
done

API=$WD/api.txt

grep ";" $LINK_FILES | \
	grep -v -e'*' -e'}' -e'_pobj_cache' -e'[S|s]oftware' | \
	gawk -F "[;]" '{ print $1 }' | sort |  uniq  > $API
