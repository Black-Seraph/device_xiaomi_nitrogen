#!/bin/bash

# Get the current script location
SCRIPT=$(readlink -f "$0")

# Get the scripts folder location
SCRIPTPATH=$(dirname "$SCRIPT")

# Navigate to the scripts folder
cd "$SCRIPTPATH"

# Navigate to the build system root
cd "../../../.."

# Remove all previously applied patches
cd system/bt
git checkout .
cd ../..
cd vendor/lineage
git checkout .
cd ../..
cd packages/apps/crDroidSettings
git checkout .
cd ../../..
cd kernel/xiaomi/nitrogen
RESETNEEDED=`git log -1 | grep wireguard | wc -l`
if [ "$RESETNEEDED" != "0" ]
then
	RESETHASH=`git rev-parse @~`
	git reset --hard $RESETHASH
fi
cd ../../..

# Pull in upstream source changes
repo sync -f --force-sync --no-tags --no-clone-bundle
cd kernel/xiaomi/nitrogen
git pull
cd ../../..

# Re-route the crDroid OTA server
cd packages/apps/crDroidSettings
git apply ../../../device/xiaomi/nitrogen/patches/reroute_crdroid_ota_server.diff
cd ../../..

# Fix Nintendo Switch Bluetooth latency
cd system/bt
git apply ../../device/xiaomi/nitrogen/patches/fix_nintendo_switch_bluetooth_latency.diff
cd ../..

# Fix COMPAT_VDSO kernel compilation (as the fix hasn't landed upstream yet)
cd vendor/lineage
PATCHNEEDED=`grep -r KERNEL_CROSS_COMPILE | grep CROSS_COMPILE_ARM32 | grep androidkernel | wc -l`
if [ "$PATCHNEEDED" != "0" ]
then
	git apply ../../device/xiaomi/nitrogen/patches/fix_compat_vdso_compilation.patch
fi
cd ../..

# Patch in wireguard into the kernel
git clone https://git.zx2c4.com/android_kernel_wireguard
cd android_kernel_wireguard
./patch-kernel.sh ../kernel/xiaomi/nitrogen
cd ..
rm -rf android_kernel_wireguard

# Build the ROM
export USE_CCACHE=1
export CCACHE_DIR=ccache
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G"
export LC_ALL=C
export CPU_SSE42=false
ccache -M 50G
. build/envsetup.sh
lunch lineage_nitrogen-userdebug
make clean
time mka otapackage
