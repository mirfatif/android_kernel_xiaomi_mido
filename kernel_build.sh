#!/bin/bash -ex

# https://gist.github.com/P1N2O/b9b2604c58aa4d7486e2fc0d327d23dc
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
# https://github.com/Neutron-Toolchains/clang-build-catalogue
# https://github.com/mvaisakh/gcc-build/releases

GCC64_DIR=/opt/gcc-arm64-12.0
GCC32_DIR=/opt/gcc-arm-12.0
LLVM_DIR=/opt/proton-clang

# kbuild environment variables
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64

# Set to empty string to avoid + sign appended to version
# EXTRAVERSION can be set in root Makefile
export LOCALVERSION='-mirfatif'

export KBUILD_BUILD_USER="irfan"
export KBUILD_BUILD_HOST="irfan-pc"

# To avoid higher version number
#rm -f out/.version

read -p 'Use LLVM? (y/N): ' key

if [ "$key" = 'y' ] || [ "$key" = 'Y' ]; then
	LLVM="ARCH=arm64 AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CC=clang HOSTCC=clang"

	# Use GCC's binutils
	#LLVM="$LLVM CROSS_COMPILE=aarch64-elf- CROSS_COMPILE_ARM32=arm-eabi-"
	#export PATH=$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH

	# Use clang's binutils
	LLVM="$LLVM CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

	export PATH=$LLVM_DIR/bin:$PATH
else
	export CROSS_COMPILE=aarch64-elf-
	export CROSS_COMPILE_ARM32=arm-eabi-
	export PATH=$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH
fi

read -p 'Do cleanup? (y/N): ' key

if [ "$key" = 'y' ] || [ "$key" = 'Y' ]; then
	[ ! -e out/.config ] || cp out/.config ./
	rm -rf out
	mkdir out
	[ ! -e .config ] || mv .config out/
fi

read -p 'Do menuconfig? (y/N): ' key

if [ "$key" = 'y' ] || [ "$key" = 'Y' ]; then
	#make O=out mido_defconfig $LLVM
	make O=out menuconfig $LLVM
fi

make -j $(nproc --all) O=out $LLVM

### COPY KERNEL IMAGE ###

# https://github.com/osm0sis/AnyKernel3
[ "$AK3_DIR" ] && [ -d "$AK3_DIR" ] && [ -f "$AK3_DIR/anykernel.sh" ]

cp out/arch/arm64/boot/Image.gz-dtb $AK3_DIR/zImage

### BUILD / COPY MODULES ###

export INSTALL_MOD_PATH="$AK3_DIR/modules/system/lib/modules"
rm -rf $INSTALL_MOD_PATH/*
make O=out modules_install $LLVM

### KEEP ONLY .ko FILES ###

find $INSTALL_MOD_PATH -type f '(' -name '*.ko' -o -name modules.alias -o -name modules.dep -o -name modules.softdep ')' | while read -r file; do
	cp "$file" $INSTALL_MOD_PATH/
done

find $INSTALL_MOD_PATH/ -type d -mindepth 1 -maxdepth 1 | while read -r dir; do
	rm -r "$dir"
done

### BUILD ZIP ###

cd $AK3_DIR
zip -r9 ~/mido_kernel_$(date +"%d-%b_%y-%T").zip * -x .git README.md *placeholder
rm -rf zImage $INSTALL_MOD_PATH/*
