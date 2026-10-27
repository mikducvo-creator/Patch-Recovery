#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-}"
if [[ -z "${IMAGE}" ]]; then
  echo "Usage: $0 <recovery.img | recovery.img.lz4 | recovery.img.xz>"
  exit 1
fi

if [[ ! -f "${IMAGE}" ]]; then
  echo "ERROR: file not found: ${IMAGE}"
  exit 1
fi

rm -f r.img r.img.lz4 r.img.xz || true

# Detect compressed image
file_type="$(file -b --mime-type "${IMAGE}" 2>/dev/null || file -b "${IMAGE}" || true)"
if echo "${file_type}" | grep -qi "lz4"; then
  cp "${IMAGE}" r.img.lz4
  lz4 -d -f r.img.lz4 r.img
elif echo "${file_type}" | grep -qi "xz"; then
  cp "${IMAGE}" r.img.xz
  xz -d -c r.img.xz > r.img
else
  cp "${IMAGE}" r.img
fi

if [[ ! -f r.img ]]; then
  echo "ERROR: failed to create r.img"
  exit 1
fi

# Generate key if missing
if [[ ! -f phh.pem ]]; then
  if ! openssl genrsa -out phh.pem 4096 >/dev/null 2>&1; then
    openssl genrsa -f4 -out phh.pem 4096
  fi
fi

echo "OK: r.img ready"
