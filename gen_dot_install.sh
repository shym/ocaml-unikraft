#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

if [ ! -e "$1.lib" -o ! -e "$1.libexec" ]; then
  echo "Usage: $0 <prefix.file.install>"
  echo "The *.install.lib and *.install.libexec for OCaml must be available."
  exit 1
fi

prefix_for_ocaml_chunks="$1"
ARCH="$2"

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

  printf '%s: [\n' libexec
  cat "$prefix_for_ocaml_chunks".libexec
  printf ']\n'

  printf '%s: [\n' lib
  cat "$prefix_for_ocaml_chunks".lib
  # dummy packages
  for pkg in threads is_unikraft; do
    install_file _build/empty lib/$pkg/META
  done
  printf ']\n'
}

main
