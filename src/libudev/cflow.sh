#!/bin/bash


# PREPROCESS='cc -c -I../libpmem2 -I../core -E'
# PREPROCESS='cc -D_FORTIFY_SOURCE=2 -DAVX512F_AVAILABLE=1 -DMOVDIR64B_AVAILABLE=1 -DNDCTL_ENABLED=1 -DSDS_ENABLED -DSTRINGOP_TRUNCATION_SUPPORTED -fno-common -fno-lto -std=gnu99 -U_FORTIFY_SOURCE -Wall -Wcast-function-type -Wconversion -Werror -Wfloat-equal -Wmissing-field-initializers -Wmissing-prototypes -Wpointer-arith -Wsign-compare -Wsign-conversion -Wswitch-default -Wunused-macros -Wunused-parameter -I. -I../../src/../src/libpmem2 -I../../src/../src/libpmem2/x86_64 -I../common/ -I../core/ -I../include -E'
# PREPROCESS='--preprocess="cc -E"'

IGNORE_STR=
# for ignore in __extension__ __endptr __leaf__ __pure__ __artificial__ __restrict __base __nothrow__ __buffer __result __n __src; do
#for ignore in inline __extension__ __leaf__ __endptr __restrict __base __nothrow__ __buffer \
#		__result __n  __src __buf __c __s2 __delim __format __len __arg __noreturn__ \
#		__size __length; do
#for ignore in __len __arg; do
#	IGNORE_STR="$IGNORE_STR -i $ignore"
#done

UDEV_STARTS=" \
udev_new  \
udev_queue_new  \
udev_queue_get_queue_is_empty  \
udev_unref  \
udev_queue_unref  \
"

STARTS=
for start in $UDEV_STARTS; do
	STARTS="$STARTS --start $start"
done

#uncomment to get full stack usage
#STARTS="$STARTS --start log_assert"
#STARTS="$STARTS --start log_assert_failed"

SOURCE="./libudev*.c ./libudev*.h ../shared/udev*.c ../shared/udev*.h ../basic/*.h  ../basic/*.c "

cflow -o ./stats/cflow.txt \
	--symbol __inline:=inline \
	--symbol __inline__:=inline \
	--symbol __const__:=const \
	--symbol __const:=const \
	--symbol __restrict:=restrict \
	--symbol __extension__:qualifier \
	--symbol __attribute__:wrapper \
	--symbol __asm__:wrapper \
	--symbol __nonnull:wrapper \
	--symbol __wur:wrapper \
	--preprocess='gcc -E -I../../src/libudev -I../../src/libudev -I../../src/basic -I../../src/basic -I../../src/fundamental -I../../src/fundamental -I../../src/systemd -I../../src/systemd -I. -I.. -I../../src/libsystemd/sd-bus -I../../src/libsystemd/sd-device -I../../src/libsystemd/sd-event -I../../src/libsystemd/sd-hwdb -I../../src/libsystemd/sd-id128 -I../../src/libsystemd/sd-journal -I../../src/libsystemd/sd-netlink -I../../src/libsystemd/sd-network -I../../src/libsystemd/sd-resolve -I../../src/shared -I../../src/shared -I../../build -fdiagnostics-color=always -D_FILE_OFFSET_BITS=64 -Wall -Winvalid-pch -Wextra -std=gnu11 -g -Wno-missing-field-initializers -Wno-unused-parameter  -Warray-bounds -Warray-bounds=2 -Wdate-time -Wendif-labels -Werror=format=2 -Werror=format-signedness -Werror=implicit-function-declaration -Werror=implicit-int -Werror=incompatible-pointer-types -Werror=int-conversion -Werror=missing-declarations -Werror=missing-prototypes -Werror=overflow -Werror=override-init -Werror=return-type -Werror=shift-count-overflow -Werror=shift-overflow=2 -Werror=undef -Wfloat-equal -Wimplicit-fallthrough=5 -Winit-self -Wlogical-op -Wmissing-include-dirs -Wmissing-noreturn -Wnested-externs -Wold-style-definition -Wpointer-arith -Wredundant-decls -Wshadow -Wstrict-aliasing=2 -Wstrict-prototypes -Wsuggest-attribute=noreturn -Wunused-function -Wwrite-strings -fdiagnostics-show-option -fno-common -fstack-protector -fstack-protector-strong --param=ssp-buffer-size=4 -Wno-maybe-uninitialized -Wno-unused-result -Werror=shadow -fPIC -fno-strict-aliasing -fvisibility=hidden -fno-omit-frame-pointer -include config.h -fvisibility=default' \
	$STARTS $IGNORE_STR $SOURCE 2> ./stats/cflow.err
