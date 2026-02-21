#!/bin/bash
set -euo pipefail

GITHUB_OWNER="vjeantet"
GITHUB_REPO="alerter"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PORTFILE="$PROJECT_DIR/macports/Portfile"

# Get version from AlerterCommand.swift
VERSION=$(grep 'version:' "$PROJECT_DIR/Sources/Alerter/AlerterCommand.swift" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ ! -f "$PORTFILE" ]; then
    echo "Error: $PORTFILE not found."
    exit 1
fi

# Download the GitHub source archive to compute checksums
ARCHIVE_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/archive/v${VERSION}.tar.gz"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

echo "==> Downloading source archive for v${VERSION}..."
curl -fsSL -o "$TMPFILE" "$ARCHIVE_URL"

ARCHIVE_RMD160=$(openssl dgst -ripemd160 "$TMPFILE" | awk '{print $NF}')
ARCHIVE_SHA256=$(shasum -a 256 "$TMPFILE" | awk '{print $1}')
ARCHIVE_SIZE=$(stat -f%z "$TMPFILE")

echo "==> Version: $VERSION"
echo "==> RMD160:  $ARCHIVE_RMD160"
echo "==> SHA256:  $ARCHIVE_SHA256"
echo "==> Size:    $ARCHIVE_SIZE"

# Update Portfile
echo "==> Updating macports/Portfile..."
sed -i '' "s|^github.setup.*|github.setup        $GITHUB_OWNER $GITHUB_REPO $VERSION v|" "$PORTFILE"
sed -i '' "s|^revision .*|revision            0|" "$PORTFILE"

# Update checksums block (replace multiline checksums with awk)
awk -v rmd160="$ARCHIVE_RMD160" -v sha256="$ARCHIVE_SHA256" -v size="$ARCHIVE_SIZE" '
/^checksums / {
    print "checksums           rmd160  " rmd160 " \\"
    print "                    sha256  " sha256 " \\"
    print "                    size    " size
    skip = 1
    next
}
skip && /^[^ ]/ { skip = 0; print ""; print; next }
skip { next }
{ print }
' "$PORTFILE" > "$PORTFILE.tmp" && mv "$PORTFILE.tmp" "$PORTFILE"

echo "==> Done!"
echo ""
echo "  macports/Portfile updated to version $VERSION"
echo ""
echo "  To submit to MacPorts, copy macports/Portfile to a PR against:"
echo "  https://github.com/macports/macports-ports/tree/master/sysutils/alerter"
