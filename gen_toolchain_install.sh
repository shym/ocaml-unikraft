#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

# Generate a .install file for the toolchain
# Takes as arguments the architecture (x86_64 or arm64) followed by all the
# toolchain tools

ARCH="$1"
shift

install_file() {
  # install_file <src> [dest]
  if [ -z "$2" ]; then
    printf '  "%s"\n' "$1"
  else
    printf '  "%s" { "%s" }\n' "$1" "$2"
  fi
}

walk_tree() {
  # walk_tree <srcprefix> [destprefix]
  # where srcprefix is not empty and destprefix ends up with a slash when set
  for f in "$1"/*; do
    base="${f##*/}"
    if [ -d "$f" ]; then
      walk_tree "$f" "$2$base/"
    else
      install_file "$f" "$2$base"
    fi
  done
}

main() {
  printf '%s: [\n' bin
  for f in "$@"; do
    install_file "$f"
  done
  printf ']\n'

  printf '%s: [\n' lib
  walk_tree _build/lib/ocaml-unikraft-toolchain-"$ARCH"
  printf ']\n'
}

main "$@"
