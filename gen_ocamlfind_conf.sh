#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

case "$1" in
  default)
    # When building the default `unikraft.conf`, the OCaml compiler this will
    # point to is assumed to be already installed in PREFIX
    ARCH=""
    PREFIX="$3/lib/ocaml-unikraft-$2"
    OCAMLDIR="$PREFIX/bin"
    ;;
  *)
    ARCH="_$1"
    PREFIX="$2/lib/ocaml-unikraft-$1"
    OCAMLDIR="ocaml"
    ;;
esac

checkopt() {
  if test -x "$OCAMLDIR"/"$1".opt; then
    printf '.opt'
  else
    printf '.byte'
  fi
}

cat << EOF
path(unikraft$ARCH) = "$PREFIX/lib"
destdir(unikraft$ARCH) = "$PREFIX/lib"
stdlib(unikraft$ARCH) = "$PREFIX/lib/ocaml"
ocamlopt(unikraft$ARCH) = "$PREFIX/bin/ocamlopt$(checkopt ocamlopt)"
ocamlc(unikraft$ARCH) = "$PREFIX/bin/ocamlc$(checkopt ocamlc)"
ocamlmklib(unikraft$ARCH) = "$PREFIX/bin/ocamlmklib"
ocamldep(unikraft$ARCH) = "$PREFIX/bin/ocamldep$(checkopt tools/ocamldep)"
ocamlcp(unikraft$ARCH) = "$PREFIX/bin/ocamlcp"
EOF
