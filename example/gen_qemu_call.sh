#!/bin/sh

# Usage: $0 <target-arch>

fatal() {
  printf '%s\n' "$1" 1>&2
  exit 1
}

one() {
  printf '%s\n' "$1"
}

two() {
  printf '%s\n%s\n' "$1" "$2"
}

check() {
    if command -v "$1" > /dev/null; then
      one "$1"
    else
      fatal "Cannot find command '$1'"
    fi
}

case "$1" in
  amd64)
    check qemu-system-x86_64
    two -device isa-debug-exit
    machine=q35
    ;;
  arm64)
    check qemu-system-aarch64
    machine=virt
    ;;
  *)
    fatal "Unsupported target architecture"
    ;;
esac

case "$CI" in
  true)
    emulate_cpu=always
    ;;
  *)
    emulate_cpu=ifneeded
    ;;
esac

case "$emulate_cpu,$(uname -m),$1" in
  ifneeded,x86_64,amd64|ifneeded,aarch64,arm64)
    two -cpu host
    one --enable-kvm
    ;;
  *,arm64)
    two -machine "$machine"
    two -cpu cortex-a53
    ;;
  *,amd64)
    two -machine "$machine"
    two -cpu 'qemu64,-vmx,-svm,+x2apic,+pdpe1gb,+rdrand,+rdseed'
    ;;
esac
