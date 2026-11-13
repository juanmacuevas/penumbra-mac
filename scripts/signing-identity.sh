#!/bin/sh
# Prints a code-signing identity for local builds.
#
# macOS ties the Accessibility permission to the app's code signature. Ad-hoc signatures change on
# every build, so the permission would be lost on each update. A self-signed certificate, created
# once in your login keychain, keeps the signature stable and the permission survives updates.
#
# Prints the certificate name, or "-" (ad-hoc) if it can't be created.

NAME="Penumbra Local Signing"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "$NAME"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

if openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
        -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1 \
   && { openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:penumbra >/dev/null 2>&1 \
        || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:penumbra >/dev/null 2>&1; } \
   && security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P penumbra -T /usr/bin/codesign >/dev/null 2>&1
then
    echo "created signing certificate \"$NAME\" in your login keychain" >&2
    echo "$NAME"
else
    echo "could not create a signing certificate; falling back to ad-hoc signing" >&2
    echo "-"
fi
