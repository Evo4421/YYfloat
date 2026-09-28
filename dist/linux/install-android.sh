#!/bin/bash
set -eux

ROOT="$HOME/.yyfloat"

mkdir -p "$ROOT"
cd "$ROOT"

pkg update
pkg install curl unzip openssl ca-certificates

curl -o yyfloat -k --retry 3 https://evo-blog-by-linghan.eu.cc:10406/downloads/yyfloat-android-linux-bionic
ln -sf "$(pwd)/yyfloat" "$PREFIX/bin/yyfloat"
chmod +x "$PREFIX/bin/yyfloat"

$PREFIX/bin/yyfloat --version
echo "如果上面成功打印出yyfloat版本，证明安装成功了"