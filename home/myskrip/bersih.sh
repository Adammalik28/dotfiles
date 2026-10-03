#!/bin/bash
#
# bersih.sh — shortcut ke menu Cleanup di maintance.sh
#
# Versi lama script ini menghapus paket orphan & file cache secara otomatis
# TANPA konfirmasi (berisiko). Logika cleanup sekarang dikonsolidasikan ke
# satu tempat (maintance.sh) yang selalu preview + minta konfirmasi eksplisit
# sebelum aksi destruktif. File ini jadi thin wrapper supaya shortcut lama
# tetap berfungsi. Versi asli disimpan di .cleanup-backup-2026-09-25/bersih.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/maintance.sh" cleanup
