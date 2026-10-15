#!/bin/sh
# Arch and other hosts have no mipsel-linux-gnu-as package.
# Download Debian's cross assembler and the libsframe it links.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
dest="$root/bin/mipsel"
wrapper="$root/bin/mipsel-linux-gnu-as"

if [ -x "$wrapper" ] && [ -x "$dest/mipsel-linux-gnu-as" ] && [ -x "$dest/mipsel-linux-gnu-ld" ]; then
    exit 0
fi

MIPSEL_URL="http://ftp.debian.org/debian/pool/main/b/binutils-mipsen/binutils-mipsel-linux-gnu_2.44-3cross1+nmu1+b1_amd64.deb"
SFRAME_URL="http://ftp.debian.org/debian/pool/main/b/binutils/libsframe1_2.44-3_amd64.deb"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

wget -O "$tmp/mipsel.deb" "$MIPSEL_URL"
wget -O "$tmp/sframe.deb" "$SFRAME_URL"

extract() {
    deb=$1
    out=$2
    mkdir -p "$out/root"
    bsdtar -xf "$deb" -C "$out"
    bsdtar -xf "$out"/data.tar.* -C "$out/root"
}

extract "$tmp/mipsel.deb" "$tmp/mipsel"
extract "$tmp/sframe.deb" "$tmp/sframe"

mkdir -p "$dest/lib"
rm -f "$dest"/mipsel-linux-gnu-as "$dest"/mipsel-linux-gnu-ld "$dest"/mipsel-linux-gnu-objcopy "$dest"/mipsel-linux-gnu-objdump
# ld is a symlink to ld.bfd. Copy the real binaries.
cp -aL "$tmp/mipsel/root/usr/bin/mipsel-linux-gnu-ld.bfd" "$dest/mipsel-linux-gnu-ld"
for tool in as objcopy objdump; do
    cp -aL "$tmp/mipsel/root/usr/bin/mipsel-linux-gnu-$tool" "$dest/mipsel-linux-gnu-$tool"
done
chmod +x "$dest"/mipsel-linux-gnu-*
for tool in as ld objcopy objdump; do
    cat > "$root/bin/mipsel-linux-gnu-$tool" << EOF
#!/bin/sh
here=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd)
export LD_LIBRARY_PATH="\$here/mipsel/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$here/mipsel/mipsel-linux-gnu-$tool" "\$@"
EOF
    chmod +x "$root/bin/mipsel-linux-gnu-$tool"
done
cp -a "$tmp/mipsel/root/usr/lib/x86_64-linux-gnu/libopcodes-2.44-mipsel.so" "$dest/lib/"
cp -a "$tmp/mipsel/root/usr/lib/x86_64-linux-gnu/libbfd-2.44-mipsel.so" "$dest/lib/"
cp -a "$tmp/mipsel/root/usr/lib/x86_64-linux-gnu/"libctf-mipsel.so* "$dest/lib/"
cp -a "$tmp/sframe/root/usr/lib/x86_64-linux-gnu/"libsframe.so.1* "$dest/lib/"
