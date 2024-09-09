#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

# Generate a .install file for a backend
# Takes as argument the backend, eg qemu-x86_64

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
      case "$f" in
        *.ld.o|*dummy*)
          # skip those
          ;;
        *.o|*.h|*.lds|*.ld)
          # we want exactly those
          install_file "$f" "$2$base"
          ;;
        *)
          # skip all others
          ;;
      esac
    fi
  done
}

if [ -z "$1" ]; then
  echo Missing backend
  exit 1
else
  printf '%s: [\n' lib
  walk_tree _build/lib/ocaml-unikraft-backend-"$1"
  printf ']\n'

  printf '%s: [\n' share
  for f in "_build/share/ocaml-unikraft-backend-$1"/*; do
    install_file "$f"
  done
  printf ']\n'
fi
