# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2023, Intel Corporation
#
# stack-usage-stat.sh -- combine stack usage into a file
# The script shall be run from the ndctl folder of the NDCTL project.
#

if [ ! -d "stats" ]; then
	mkdir stats
else
	rm -rf stats/stack-usage*
fi

for build in libudev-basic.a.p; do
	grep -v ^$ ../../build/src/libudev/$build/*.su | \
	gawk -F "[:\t]" '{print $6 " " $5 " : " $1 ":" $2 " " $7}' | \
	sort -n -r > stats/stack-usage-`echo $build | sed 's/\//_/'`.txt
done

#for build in libdaxctl.so.1.2.5.p; do
#	grep -v ^$ ../../build/daxctl/lib/$build/*.su | \
#	gawk -F "[:\t]" '{print $5 " " $4 " : " $1 ":" $2 " " $6}' | \
#	sort -n -r > stats/stack-usage-`echo $build | sed 's/\//_/'`.txt
#done
