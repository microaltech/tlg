#!/usr/bin/env bash
# Membuat keystore rilis Android (sekali saja per aplikasi).
#
#   tools/make_keystore.sh [path-keystore] [alias]
#
# PENTING: simpan keystore dan kata sandinya di tempat aman (mis. password
# manager + cadangan offline). Kalau hilang, Anda tidak bisa memperbarui aplikasi
# di Google Play kecuali memakai Play App Signing. Jangan commit ke git.
set -euo pipefail

KEYSTORE="${1:-$HOME/keys/toplordlike-release.keystore}"
ALIAS="${2:-toplordlike}"

if [[ -e "$KEYSTORE" ]]; then
	echo "Keystore sudah ada: $KEYSTORE (tidak ditimpa)." >&2
	exit 1
fi
mkdir -p "$(dirname "$KEYSTORE")"

read -r -s -p "Kata sandi keystore (min. 6 karakter): " PASS
echo
read -r -s -p "Ulangi kata sandi: " PASS2
echo
if [[ "$PASS" != "$PASS2" || ${#PASS} -lt 6 ]]; then
	echo "Kata sandi tidak cocok atau terlalu pendek." >&2
	exit 1
fi
read -r -p "Nama pengembang/perusahaan (untuk sertifikat): " ORG

keytool -genkeypair -v \
	-keystore "$KEYSTORE" -alias "$ALIAS" \
	-keyalg RSA -keysize 2048 -validity 10000 \
	-storepass "$PASS" -keypass "$PASS" \
	-dname "CN=${ORG:-Top Lord Like}, O=${ORG:-Top Lord Like}, C=ID"
chmod 600 "$KEYSTORE"

cat <<MSG

Keystore dibuat: $KEYSTORE
Sebelum build rilis, set environment variable berikut (mis. di ~/.bashrc lokal,
JANGAN di repo):

  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<kata sandi tadi>"

Lalu: GODOT=/path/ke/godot tools/build_android.sh aab
MSG
