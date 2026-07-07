#!/bin/bash
# Creates a self-signed code-signing identity ("Shell Drive Dev") in your login
# keychain. build.sh then signs with it, so macOS Accessibility / Automation
# permissions PERSIST across rebuilds (ad-hoc signatures change every build and
# force you to re-grant permission each time).
#
# This is a local DEVELOPER convenience only — it does NOT enable distribution
# to other Macs (that still needs an Apple Developer ID + notarization).
set -euo pipefail

CN="Shell Drive Dev"

if security find-certificate -c "$CN" >/dev/null 2>&1; then
    echo "✓ Identity '$CN' already exists. Nothing to do."
    exit 0
fi

echo "→ Generating self-signed code-signing certificate '$CN'…"
TMP="$(mktemp -d)"
cat > "$TMP/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Shell Drive Dev
[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -days 3650 -nodes -newkey rsa:2048 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -config "$TMP/openssl.cnf" -extensions v3 >/dev/null 2>&1

# Apple-compatible PKCS#12 (legacy 3DES/SHA1 so the keychain can import it).
openssl pkcs12 -export -out "$TMP/id.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout pass:shelldrive -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 >/dev/null 2>&1

# Import; -A lets codesign use the key without an interactive keychain prompt.
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "shelldrive" -A -T /usr/bin/codesign

rm -rf "$TMP"
echo "✓ Created '$CN'. Rebuild with ./build.sh; grant Accessibility once and it sticks."
