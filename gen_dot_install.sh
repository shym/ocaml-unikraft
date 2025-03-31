#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

ARCH="$1"

install_file() {
  # install_file <src> [dest]
  if [ -z "$2" ]; then
    printf '  "%s"\n' "$1"
  else
    printf '  "%s" { "%s" }\n' "$1" "$2"
  fi
}

main() {
  printf '%s: [\n' lib_root
  install_file _build/unikraft_"$ARCH".conf findlib.conf.d/unikraft_"$ARCH".conf
  printf ']\n'

  printf '%s: [\n' lib
  # dummy packages
  for pkg in threads is_unikraft; do
    install_file _build/empty lib/$pkg/META
  done
  printf ']\n'
}

main
