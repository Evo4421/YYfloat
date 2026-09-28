#!/bin/bash
set -eux

ARCH=$(uname -m)
ROOT="$HOME/.yyfloat"

mkdir -p "$ROOT"
if [[ "$ARCH" == x86_64* || "$ARCH" == amd64* ]] then
    cd ROOT
    curl -o yyfloat -k --retry 3 https://evo-blog-by-linghan.eu.cc:10406/downloads/yyfloat-x86_64-linux-gnu
    ln -sf "$(pwd)/yyfloat" /usr/local/bin/yyfloat
    chmod +x /usr/local/bin/yyfloat
elif [[ "$ARCH" == aarch64* || "$ARCH" == arm64* ]] then
    cd ROOT
    curl -o yyfloat -k --retry 3 https://evo-blog-by-linghan.eu.cc:10406/downloads/yyfloat-aarch64-linux-gnu
    ln -sf "$(pwd)/yyfloat" /usr/local/bin/yyfloat
    chmod +x /usr/local/bin/yyfloat
fi