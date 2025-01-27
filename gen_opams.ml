(* SPDX-License-Identifier: MIT
 * Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>
 *)

(* OCaml script to generate all the *.opam files *)

let version_ocaml_unikraft = "0.0.1"
let version_unikraft = "0.18.0"
let archs = [ "arm64"; "x86_64" ]
let backends = [ ("fc", "FireCracker"); ("qemu", "QEMU") ]

let options =
  [
    ("debug", "debugging", []);
    ("lwip", "the lwIP library", [ "network-stack" ]);
    ("ocaml-net-stack", "OCaml network stack", [ "network-stack" ]);
  ]

let with_package package_name gen =
  let filename = Printf.sprintf "%s.opam" package_name in
  Out_channel.with_open_bin filename (fun out ->
      Printf.fprintf out
        {|opam-version: "2.0"
name: "%s"
maintainer: "samuel@tarides.com"
homepage: "https://github.com/shym/ocaml-unikraft/"
bug-reports: "https://github.com/shym/ocaml-unikraft/issues"|}
        package_name;
      gen out)

let backend_package arch backend =
  let short_name, long_name = backend in
  let package_name =
    Printf.sprintf "ocaml-unikraft-backend-%s-%s" short_name arch
  in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis: "%s/%s Unikraft backend for OCaml"
authors: ["Samuel Hym" "Unikraft contributors"]
license: ["MIT" "BSD-3-Clause" "GPL-2.0-only"]
depends: [
  "unikraft" {= version}
]
depopts: [|}
        version_unikraft long_name arch;
      List.iter
        (fun (opt, _, _) ->
          Printf.fprintf out "\n  \"ocaml-unikraft-option-%s\"" opt)
        options;
      Printf.fprintf out
        {|
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "UNIKRAFT=%%{lib}%%/unikraft"
    "OCUKPLAT=%s"
    "OCUKARCH=%s"
    "OCUKEXTLIBS=musl"
    "OCUKEXTLIBS+=lwip" {ocaml-unikraft-option-lwip:installed}
    "OCUKCONFIGOPTS+=debug" {ocaml-unikraft-option-debug:installed}
    "%%{name}%%.install"
  ]
]
extra-source "lib-lwip.tar.gz" {
  src:
    "https://github.com/unikraft/lib-lwip/archive/refs/tags/RELEASE-0.18.0.tar.gz"
  checksum:
    "sha256=f785f9523e27704cf86050c5d8108ffbc45f8bdf6dccacbf5dd6f3dfcadbdb77"
}
extra-source "lib-musl.tar.gz" {
  src:
    "https://github.com/unikraft/lib-musl/archive/refs/tags/RELEASE-0.18.0.tar.gz"
  checksum:
    "sha256=b51afee0227c0c8c419dd001fb6b6f57b529e5cadcd437afdd05e2e8667a1e2e"
}
extra-source "patches/lib-musl/main-tsd.patch" {
  src:
    "https://github.com/shym/lib-musl/commit/c6fdfa79e23e6d52df2c2d28e4eb13e91b16ad4c.patch"
  checksum:
    "sha256=9b87cbf0743492e6949de61af6423b463031da8b14b799a775c34886cabffd28"
}
extra-source "patches/lib-musl/arm64.patch" {
  src:
    "https://github.com/shym/lib-musl/commit/ecae7ade7bcf7e0fb7e869225f6db1043d3653bf.patch"
  checksum:
    "sha256=d83043f534a8da4f0133f4fbde0d78bc3a5d996ca6f7fc91b42ccf2874515514"
}
extra-source "lwip-UNIKRAFT-2_1_x.zip" {
  src:
    "https://github.com/unikraft/fork-lwip/archive/refs/heads/UNIKRAFT-2_1_x.zip"
  checksum:
    "sha256=1cf15ac8a70946f49327cfa4bc6923555b8c4ceeb11e4dc4f20e530b674403af"
}
extra-source "musl-1.2.3.tar.gz" {
  src: "https://www.musl-libc.org/releases/musl-1.2.3.tar.gz"
  checksum:
    "sha256=7d5b0b6062521e4627e099e4c9dc8248d32a30285e959b7eecaa780cf8cfd4a4"
}
|}
        short_name arch)

let option_package option =
  let short_name, long_name, conflicts = option in
  let package_name = Printf.sprintf "ocaml-unikraft-option-%s" short_name in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis:
  "Virtual package to enable %s in the Unikraft backends"
authors: "Samuel Hym"
license: "MIT"
|}
        version_unikraft long_name;
      match conflicts with
      | [] -> ()
      | _ ->
          Printf.fprintf out "conflict-class: [\n";
          List.iter
            (Printf.fprintf out "  \"ocaml-unikraft-%s\"\n")
            conflicts;
          Printf.fprintf out "]\n")

let toolchain_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-toolchain-%s" arch in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis:
  "C toolchain to build an OCaml cross-compiler to the freestanding Unikraft %s backends"
description:
  "This package provides a C toolchain to build an OCaml cross-compiler, suitable for linking with a Unikraft %s unikernel."
authors: "Samuel Hym"
license: "MIT"
depends: [
  "ocaml-unikraft-backend-qemu-%s" | "ocaml-unikraft-backend-fc-%s"
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "LIB=%%{lib}%%"
    "SHARE=%%{share}%%"
    "OCUKARCH=%s"
    "%%{name}%%.install"
  ]
]
|}
        version_ocaml_unikraft arch arch arch arch arch)

let compiler_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-%s" arch in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis: "OCaml cross-compiler to the freestanding Unikraft %s backends"
description:
  "This package provides a OCaml cross-compiler, suitable for linking with a Unikraft %s unikernel."
authors: "Samuel Hym"
license: ["MIT" "LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception"]
depends: [
  "ocaml" {>= "5.2.0" & <= "5.2.1"}
  "ocaml-unikraft-toolchain-%s"
  "ocamlfind"
  "ocaml-src" {build}
  "conf-git" {build}
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "prefix=%%{prefix}%%"
    "BIN=%%{bin}%%"
    "LIB=%%{lib}%%"
    "SHARE=%%{share}%%"
    "OCUKARCH=%s"
    "%%{name}%%.install"
  ]
]
|}
        version_ocaml_unikraft arch arch arch arch)

let default_compiler_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-default-%s" arch in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis:
  "OCaml default cross-compiler to the freestanding Unikraft %s backends"
description:
  "This package provides a OCaml cross-compiler, suitable for linking with a Unikraft %s unikernel, as the default `unikraft` ocamlfind toolchain."
authors: "Samuel Hym"
license: "MIT"
depends: ["ocaml-unikraft-%s" "ocamlfind"]
conflict-class: "ocaml-unikraft-default"
build: [
  [make "prefix=%%{prefix}%%" "OCUKARCH=%s" "%%{name}%%.install"]
]
|}
        version_ocaml_unikraft arch arch arch arch)

let default_backend_package backend =
  let short_name, long_name = backend in
  let package_name = Printf.sprintf "ocaml-unikraft-backend-%s" short_name in
  with_package package_name (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis:
  "Virtual package to ensure the %s Unikraft backend is installed for the default cross-compiler"
description:
  "This virtual package ensures that the %s backend is installed for the default `unikraft` ocamlfind cross toolchain."
authors: "Samuel Hym"
license: "MIT"
depends: [
  "ocaml-unikraft"
  ("ocaml-unikraft-default-x86_64" & "ocaml-unikraft-backend-%s-x86_64") |
  ("ocaml-unikraft-default-arm64" & "ocaml-unikraft-backend-%s-arm64")
]
|}
        version_ocaml_unikraft long_name long_name short_name short_name)

let main_package () =
  with_package "ocaml-unikraft" (fun out ->
      Printf.fprintf out
        {|
version: "%s"
synopsis:
  "Virtual package to install one of the OCaml default cross-compilers to the freestanding Unikraft backends"
description:
  "This virtual package ensures that an OCaml cross-compiler is available for linking with a Unikraft unikernel as the default `unikraft` ocamlfind toolchain. Explicitly choose one among the ocaml-unikraft-default-* packages to control which one is actually installed."
authors: "Samuel Hym"
license: "MIT"
depends: ["ocaml-unikraft-default-x86_64" | "ocaml-unikraft-default-arm64"]
|}
        version_ocaml_unikraft)

let _ =
  List.iter (fun arch -> List.iter (backend_package arch) backends) archs;
  List.iter option_package options;
  List.iter toolchain_package archs;
  List.iter compiler_package archs;
  List.iter default_compiler_package archs;
  List.iter default_backend_package backends;
  main_package ()
