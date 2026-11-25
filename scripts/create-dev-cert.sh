#!/bin/bash
# One-time: creates a local self-signed "Cove Dev" code signing identity.
# With a stable signature, macOS keeps Accessibility/Bluetooth permissions across rebuilds.
set -euo pipefail
NAME="Cove Dev"
if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "\"$NAME\" already exists."; exit 0
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
LEGACY=""; openssl version | grep -q "^OpenSSL 3" && LEGACY="-legacy"
openssl pkcs12 -export $LEGACY -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/cove.p12" -passout pass:cove
security import "$TMP/cove.p12" -k ~/Library/Keychains/login.keychain-db -P cove -T /usr/bin/codesign
echo "Trusting the certificate for code signing (macOS will ask for your password)..."
security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem"
echo "Done. Run ./scripts/install.sh, then grant Accessibility one last time."
