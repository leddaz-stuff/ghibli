#!/bin/bash
#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.

# Setup getopt.
long_opts="regen,clean,sdclang,homedir:,tcdir:"
getopt_cmd=$(getopt -o rcsuh:t: --long "$long_opts" \
            -n $(basename $0) -- "$@") || \
            { echo -e "\nError: Getopt failed. Extra args\n"; exit 1;}

eval set -- "$getopt_cmd"

while true; do
    case "$1" in
        -r|--regen|r|regen) FLAG_REGEN_DEFCONFIG=y;;
        -c|--clean|c|clean) FLAG_CLEAN_BUILD=y;;
        -s|--sdclang|s|sdclang) FLAG_SDCLANG_BUILD=y;;
        -h|--homedir|h|homedir) HOME_DIR="$2"; shift;;
        -t|--tcdir|t|tcdir) TC_DIR="$2"; shift;;
        -o|--outdir|o|outdir) OUT_DIR="$2"; shift;;
        --) shift; break;;
    esac
    shift
done

# Setup HOME dir
if [ $HOME_DIR ]; then
    HOME_DIR=$HOME_DIR
else
    HOME_DIR=$HOME
fi
echo -e "HOME directory is at $HOME_DIR\n"

# Setup OUT dir
if [ $OUT_DIR ]; then
    OUT_DIR=$OUT_DIR
else
    OUT_DIR=out
fi
echo -e "Out directory is at $OUT_DIR\n"

export KBUILD_BUILD_USER=leddaz
export KBUILD_BUILD_HOST=totoro

SECONDS=0 # builtin bash timer
ZIPNAME="LagoDuria+Tiramisu-miatoll-$(date '+%Y%m%d-%H%M').zip"
if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
        ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/xiaomi/miatoll_defconfig"

# Prep for a clean build, if requested so
if [ "$FLAG_CLEAN_BUILD" = 'y' ]; then
	echo -e "\nCleaning output folder..."
	rm -rf $OUT_DIR
fi

# Regenerate defconfig, if requested so
if [ "$FLAG_REGEN_DEFCONFIG" = 'y' ]; then
	make O=$OUT_DIR ARCH=arm64 $DEFCONFIG savedefconfig
	cp $OUT_DIR/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit 1
fi

mkdir -p $OUT_DIR
KDIR=$(pwd)
export KDIR

if [ ! -d "${KDIR}/gcc64" ]; then
        curl -sL https://github.com/cyberknight777/gcc-arm64/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm64-master "${KDIR}"/gcc64
    fi

    if [ ! -d "${KDIR}/gcc32" ]; then
	curl -sL https://github.com/cyberknight777/gcc-arm/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm-master "${KDIR}"/gcc32
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        LD="${KDIR}"/gcc64/bin/aarch64-elf-ld.lld
        HOSTLD="${pwd}"/gcc64/bin/aarch64-elf-ld.lld
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
    )

echo -e "\nStarting compilation...\n"
make O=$OUT_DIR ARCH=arm64 $DEFCONFIG
make -j"$(nproc --all)" O=$OUT_DIR ARCH=arm64 O=out CROSS_COMPILE=aarch64-elf- CROSS_COMPILE_ARM32=arm-eabi- LD="${KDIR}"/gcc64/bin/aarch64-elf-ld.lld HOSTLD="${KDIR}"/gcc64/bin/aarch64-elf-ld.lld AR=llvm-ar NM=llvm-nm OBJDUMP=llvm-objdump OBJCOPY=llvm-objcopy OBJSIZE=llvm-objsize STRIP=llvm-strip HOSTAR=llvm-ar HOSTCC=gcc HOSTCXX=aarch64-elf-g++ CC=aarch64-elf-gcc Image dtbo.img

if [ -f "$OUT_DIR/arch/arm64/boot/Image" ] && [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
		git -C AnyKernel3 checkout miatoll &> /dev/null
	elif ! git clone -q https://github.com/LeddaZ/AnyKernel3 -b miatoll; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
	cp $OUT_DIR/arch/arm64/boot/Image AnyKernel3
	cp $OUT_DIR/arch/arm64/boot/dtbo.img AnyKernel3
	cp $OUT_DIR/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb AnyKernel3/dtb
	rm -f ./*zip
	cd AnyKernel3 || exit
	rm -rf $OUT_DIR/arch/arm64/boot
	zip -r9 "../$ZIPNAME" ./* -x '*.git*' README.md ./*placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	echo
else
	echo -e "\nCompilation failed!"
fi
