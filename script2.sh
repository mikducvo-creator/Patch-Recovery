#!/bin/bash
set -Eeuo pipefail

mkdir -p unpack
cd unpack

echo "Unpacking recovery image..."
../magiskboot unpack ../r.img || {
  echo "ERROR: Failed to unpack r.img"
  exit 1
}

ramdisk="ramdisk.cpio"
if [ -f vendor_ramdisk/recovery.cpio ]; then
    ramdisk="vendor_ramdisk/recovery.cpio"
elif [ -f vendor_ramdisk_recovery.cpio ]; then
    ramdisk="vendor_ramdisk_recovery.cpio"
fi

echo "Extracting ramdisk: $ramdisk"
../magiskboot cpio "$ramdisk" extract || {
  echo "ERROR: Failed to extract ramdisk"
  exit 1
}

if [ ! -f system/bin/recovery ]; then
  echo "ERROR: system/bin/recovery not found in extracted ramdisk"
  find . -maxdepth 4 -type f | sed 's#^\./##' | head -200
  exit 1
fi

patch_if_found() {
  local old="$1"
  local new="$2"

  if ../magiskboot hexpatch system/bin/recovery "$old" "$new"; then
    echo "Patched: $old -> $new"
  else
    echo "Skip (pattern not found): $old"
  fi
}

# Reverse fastbootd ENG mode check
patch_if_found e10313aaf40300aa6ecc009420010034 e10313aaf40300aa6ecc0094
patch_if_found eec3009420010034 eec3009420010035
patch_if_found 3ad3009420010034 3ad3009420010035
patch_if_found 50c0009420010034 50c0009420010035
patch_if_found 080109aae80000b4 080109aae80000b5
patch_if_found 20f0a6ef38b1681c 20f0a6ef38b9681c
patch_if_found 23f03aed38b1681c 23f03aed38b9681c
patch_if_found 20f09eef38b1681c 20f09eef38b9681c
patch_if_found 26f0ceec30b1681c 26f0ceec30b9681c
patch_if_found 24f0fcee30b1681c 24f0fcee30b9681c
patch_if_found 27f02eeb30b1681c 27f02eeb30b9681c
patch_if_found b4f082ee28b1701c b4f082ee28b970c1
patch_if_found 9ef0f4ec28b1701c 9ef0f4ec28b9701c
patch_if_found 9ef00ced28b1701c 9ef00ced28b9701c
patch_if_found 2001597ae0000054 2001597ae1000054
patch_if_found 2001597ac0000054 2001597ac1000054
patch_if_found 9ef0fcec28b1701c 9ef0fced28b1701c
patch_if_found 9ef00ced28b1701c 9ef00ced28b9701c
patch_if_found 24f0f2ea30b1681c 24f0f2ea30b9681c
patch_if_found e0031f2a8e000014 200080528e000014
patch_if_found 41010054a0020012f44f48a9 4101005420008052f44f48a9

echo "Repacking ramdisk..."
../magiskboot cpio "$ramdisk" 'add 0755 system/bin/recovery system/bin/recovery' || {
  echo "ERROR: Failed to add patched recovery binary back into ramdisk"
  exit 1
}

../magiskboot repack ../r.img new-boot.img || {
  echo "ERROR: Failed to repack recovery image"
  exit 1
}

cp -f new-boot.img ../r-patched.img
echo "Patched image created: ../r-patched.img"
