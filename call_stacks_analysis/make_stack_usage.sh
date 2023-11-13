#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2023, Intel Corporation
#
#
# Combine stack usage into a file.
#

BUILD=${1-nondebug} # debug or nondebug

WD=$(realpath $(dirname $0))
TOP=$(realpath $WD/..)
SRC=src/$BUILD

cd $TOP

SU_FILES=`find ./build/src/ -name *.su`

grep -v ^$ $SU_FILES | \
	gawk -F "[:\t]" '{print $6 " " $5 " : " $1 ":" $2 " " $7}' | \
	sort -n -r > $WD/stack_usage.txt

cd - > /dev/null

#for build in libudev-basic.a.p; do
#	grep -v ^$ `find ../../build/src/ -name *.su` | \
#	gawk -F "[:\t]" '{print $6 " " $5 " " $7}' | \
#	sort -n -r > stats/stack-usage-`echo $build | sed 's/\//_/'`.txt
#done