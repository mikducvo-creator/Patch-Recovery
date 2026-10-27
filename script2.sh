#!/usr/bin/env bash
set -Eeuo pipefail

TARGET="${1:-r.img}"
if [[ ! -f "${TARGET}" ]]; then
  echo "ERROR: ${TARGET} not found"
  exit 1
fi

rm -rf unpack || true
mkdir -p unpack
cd unpack

echo "==> Unpacking ${TARGET}"
../magiskboot unpack ../r.img || {
  echo "ERROR: failed to unpack image"
  exit 1
}

ramdisk=""
if [[ -f "vendor_ramdisk/recovery.cpio" ]]; then
  ramdisk="vendor_ramdisk/recovery.cpio"
elif [[ -f "vendor_ramdisk_recovery.cpio" ]]; then
  ramdisk="vendor_ramdisk_recovery.cpio"
elif [[ -f "ramdisk.cpio" ]]; then
  ramdisk="ramdisk.cpio"
else
  echo "ERROR: no recovery ramdisk found in unpacked image"
  exit 1
fi

echo "Using ramdisk: ${ramdisk}"

../magiskboot cpio "${ramdisk}" extract || {
  echo "ERROR: failed to extract ramdisk"
  exit 1
}

hexpatch_if_present() {
  local file="$1"
  local old="$2"
  local new="$3"

  if [[ ! -f "${file}" ]]; then
    echo "WARN: ${file} not found, skipping patch"
    return 0
  fi

  local current_hex
  current_hex="$(xxd -p "${file}" | tr -d '\n' | tr 'A-F' 'a-f')"
  local target_hex="${old,,}"

  if [[ "${current_hex}" != *"${target_hex}"* ]]; then
    echo "INFO: pattern not present in ${file}; skipping patch: ${old}"
    return 0
  fi

  echo "Patching ${file}: ${old} -> ${new}"
  ../magiskboot hexpatch "${file}" "${old}" "${new}"
}

# Patch common stock recovery checks
hexpatch_if_present "system/bin/recovery" "e10313aaf40300aa6ecc009420010034" "e10313aaf40300aa6ecc0094"
hexpatch_if_present "system/bin/recovery" "eec3009420010034" "eec3009420010035"
hexpatch_if_present "system/bin/recovery" "3ad3009420010034" "3ad3009420010035"
hexpatch_if_present "system/bin/recovery" "50c0009420010034" "50c0009420010035"
hexpatch_if_present "system/bin/recovery" "080109aae80000b4" "080109aae80000b5"
hexpatch_if_present "system/bin/recovery" "20f0a6ef38b1681c" "20f0a6ef38b9681c"
hexpatch_if_present "system/bin/recovery" "23f03aed38b1681c" "23f03aed38b9681c"
hexpatch_if_present "system/bin/recovery" "20f09eef38b1681c" "20f09eef38b9681c"
hexpatch_if_present "system/bin/recovery" "26f0ceec30b1681c" "26f0ceec30b9681c"
hexpatch_if_present "system/bin/recovery" "24f0fcee30b1681c" "24f0fcee30b9681c"
hexpatch_if_present "system/bin/recovery" "27f02eeb30b1681c" "27f02eeb30b9681c"
hexpatch_if_present "system/bin/recovery" "b4f082ee28b1701c" "b4f082ee28b970c1"
hexpatch_if_present "system/bin/recovery" "9ef0f4ec28b1701c" "9ef0f4ec28b9701c"
hexpatch_if_present "system/bin/recovery" "9ef00ced28b1701c" "9ef00ced28b9701c"
hexpatch_if_present "system/bin/recovery" "2001597ae0000054" "2001597ae1000054"
hexpatch_if_present "system/bin/recovery" "2001597ac0000054" "2001597ac1000054"
hexpatch_if_present "system/bin/recovery" "9ef0fcec28b1701c" "9ef0fced28b1701c"
hexpatch_if_present "system/bin/recovery" "9ef00ced28b1701c" "9ef00ced28b9701c"
hexpatch_if_present "system/bin/recovery" "24f0f2ea30b1681c" "24f0f2ea30b9681c"
hexpatch_if_present "system/bin/recovery" "e0031f2a8e000014" "200080528e000014"
hexpatch_if_present "system/bin/recovery" "41010054a0020012f44f48a9" "4101005420008052f44f48a9"

# Repack ramdisk back in
../magiskboot cpio "${ramdisk}" 'add 0755 system/bin/recovery system/bin/recovery' || {
  echo "ERROR: failed to add patched recovery binary back into ramdisk"
  exit 1
}

../magiskboot repack ../r.img new-boot.img || {
  echo "ERROR: failed to repack image"
  exit 1
}

cp -f new-boot.img ../r-patched.img

if [[ ! -f ../r-patched.img ]]; then
  echo "ERROR: output image not created"
  exit 1
fi

echo "OK: patched image created: ../r-patched.img"
