# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>

# CONFIGURATION
#################

# Target platform: qemu, fc or xen
ifeq ("$(origin PLAT)","undefined")
PLAT := qemu
endif
# Target architecture: x86_64 or arm64
ifeq ("$(origin TGTARCH)","undefined")
TGTARCH := x86_64
endif
STDARCH := $(subst arm64,aarch64,$(TGTARCH))
# Installation prefix for OCaml
ifeq ("$(origin prefix)","undefined")
prefix := /usr/local
endif

BLDLIB := _build/lib
BLDSHARE := _build/share
BLDBIN := _build/bin
# The following can be overriden to build the toolchain using installed backends
LIB := $(BLDLIB)
SHARE := $(BLDSHARE)
BIN := $(BLDBIN)

# Absolute path to the Unikraft sources
ifeq ("$(origin UNIKRAFT)","undefined")
UNIKRAFT := $(LIB)/unikraft
endif
ifeq ("$(filter /%,$(UNIKRAFT))","")
override UNIKRAFT := "$$PWD"/$(UNIKRAFT)
endif

# Tar command that extracts an archive stripping the first directory
UNTARSTRIP := tar -x --strip-components=1
# Create a hard link
HARDLINK := ln -f
# Create a symbolic link
SYMLINK := ln -sf

BACKENDPKG := ocaml-unikraft-backend-$(PLAT)-$(TGTARCH)
TOOLCHAINPKG := ocaml-unikraft-toolchain-$(TGTARCH)
OCAMLPKG := ocaml-unikraft-$(TGTARCH)
BELIBDIR := $(LIB)/$(BACKENDPKG)
BEBLDLIBDIR := $(BLDLIB)/$(BACKENDPKG)
SHAREDIR := $(SHARE)/$(BACKENDPKG)
BLDSHAREDIR := $(BLDSHARE)/$(BACKENDPKG)
# Dummy files that are touched when the backend and the compiler have been built
BACKENDBUILT := _build/$(PLAT)-$(TGTARCH)_built
OCAMLBUILT := _build/ocaml_built

.PHONY: all
all: compiler


# BUILD OF DUMMYKERNEL
########################

LIBMUSL := _build/libs/musl
MUSLARCHIVE := $(wildcard musl-*.tar.gz)
MUSLARCHIVEPATH := $(BEBLDLIBDIR)/libmusl/$(MUSLARCHIVE)
LIBLWIP := _build/libs/lwip
LWIPARCHIVE := $(wildcard lwip-*.zip)
LWIPARCHIVEPATH := $(BEBLDLIBDIR)/liblwip/$(patsubst lwip-%,%,$(LWIPARCHIVE))
CONFIG := dummykernel/$(PLAT)-$(TGTARCH).fullconfig

UKMAKE := umask 0022 && \
   $(MAKE) -C $(BEBLDLIBDIR) \
       CONFIG_UK_BASE="$(UNIKRAFT)/" \
       O="$$PWD/$(BEBLDLIBDIR)/" \
       A="$$PWD/dummykernel/" \
       L="$$PWD/$(LIBMUSL):$$PWD/$(LIBLWIP)" \
       N=dummykernel \
       C="$$PWD/$(CONFIG)"

# Main build rule for the dummy kernel
$(BACKENDBUILT): $(CONFIG) | $(BEBLDLIBDIR)/Makefile $(LIB)/unikraft \
    $(MUSLARCHIVEPATH) $(LIBMUSL) $(LWIPARCHIVEPATH) $(LIBLWIP)
	+$(UKMAKE) sub_make_exec=1
	touch $@

_build/libs/%: lib-%.tar.gz
	mkdir -p $@
	$(UNTARSTRIP) -f $< -C $@

$(MUSLARCHIVEPATH): $(MUSLARCHIVE)
	mkdir -p $(dir $@)
	$(HARDLINK) $< $@

$(LWIPARCHIVEPATH): $(LWIPARCHIVE)
	mkdir -p $(dir $@)
	$(HARDLINK) $< $@

# Enabled only on Linux (requirement of the olddefconfig target) and in
# development (no need to rebuild the configuration in release)
$(CONFIG): dummykernel/$(PLAT)-$(TGTARCH).config \
    | $(BEBLDLIBDIR)/Makefile $(LIBMUSL) $(LIBLWIP)
	if [ -e .git -a "`uname`" = Linux ]; then \
	    cp $< $@; \
	    $(UKMAKE) olddefconfig; \
	else \
	    touch $@; \
	fi

# Build the intermediate configuration file from configuration chunks
CONFIG_CHUNKS := arch/$(TGTARCH) plat/$(PLAT)
CONFIG_CHUNKS += libs/base libs/lwip libs/musl
CONFIG_CHUNKS += opts/base
# The full debug info is really verbose
# CONFIG_CHUNKS += opts/debug

dummykernel/$(PLAT)-$(TGTARCH).config: \
  $(addprefix dummykernel/config/, $(CONFIG_CHUNKS))
	cat $^ > $@

# Rebuild all the full configurations
.PHONY: fullconfigs
fullconfigs:
	+for p in qemu fc xen; do \
	    for a in x86_64 arm64; do \
	        $(MAKE) PLAT=$$p TGTARCH=$$a dummykernel/$$p-$$a.fullconfig ; \
	    done \
	done

$(BEBLDLIBDIR)/Makefile: | $(BEBLDLIBDIR)
	test -e $(UNIKRAFT)/Makefile
	$(SYMLINK) $(UNIKRAFT)/Makefile $@


# EXTRACTION OF BUILD INFO
############################
# Learn how to build a unikernel: flags for the compiler, for the linker, how to
# post-process the image, ...

$(BEBLDLIBDIR)/appdummykernel/dummymain.o.cmd: $(BACKENDBUILT) ;

# Use an implicit rule to generate all files in one rule
.PRECIOUS: $(BLDSHARE)/%/cflags $(BLDSHARE)/%/cc $(BLDSHARE)/%/toolprefix
$(BLDSHARE)/%/cflags $(BLDSHARE)/%/cc $(BLDSHARE)/%/toolprefix: \
    _build/lib/%/appdummykernel/dummymain.o.cmd $(BACKENDBUILT) | $(BLDSHAREDIR)
	bash extract_cc_opts.sh "$(UNIKRAFT)" "$$PWD/$(BEBLDLIBDIR)" $< \
	    $(BLDSHARE)/$*/cflags $(BLDSHARE)/$*/cc $(BLDSHARE)/$*/toolprefix

# This rule depends on $(BACKENDBUILT) rather than the .cmd file since its
# exact name can vary depending on the backend (namely with an extra `.elf`
# extension on xen)
$(BLDSHAREDIR)/ldflags: $(BACKENDBUILT) | $(BLDSHAREDIR)
	bash extract_cc_opts.sh "$(UNIKRAFT)" "$$PWD/$(BEBLDLIBDIR)" \
	    "$(BEBLDLIBDIR)/"dummykernel_*.dbg.cmd $@

$(BLDSHAREDIR)/.suffix: $(BACKENDBUILT) | $(BLDSHAREDIR)
	suffix=`basename "$(BEBLDLIBDIR)"/dummykernel_*.dbg` ; \
	    printf %s "$${suffix#*.}" > $@

# Post-processing steps
# We rebuild the final image in verbose mode, to extract the post-processing
# steps (we redirect the log into a file because the verbose mode is really
# really verbose)
# We copy the config preserving the timestamp to avoid rebuilds due to silly
# changes, but we still log the diff so that if something really changed, we can
# debug it
$(BLDSHAREDIR)/.poststeps.log: $(BACKENDBUILT) | $(BLDSHAREDIR)
	if ! diff -u $(CONFIG) $(BEBLDLIBDIR)/config ; then \
	    cp -p $(CONFIG) $(BEBLDLIBDIR)/config; \
	fi
	+$(UKMAKE) sub_make_exec=1 -W "$$PWD/$(BEBLDLIBDIR)"/dummykernel_*.dbg \
	    --no-print-directory V=1 > $@

$(BLDSHAREDIR)/poststeps: $(BLDSHAREDIR)/.poststeps.log $(BLDSHAREDIR)/.suffix
	sed -e '/^[*A-Z]/d' \
	    -e '/^cmp.*fullconfig.*config/d' \
	    -e '/sh provided_syscalls.in/d' \
	    -e '/sh libraries.in/d' $(BLDSHAREDIR)/.poststeps.log \
	| bash extract_postprocessing.sh "$(UNIKRAFT)" \
	    "$$PWD/$(BEBLDLIBDIR)" dummykernel_$(PLAT)-$(TGTARCH) \
	    $(BLDSHAREDIR)/.suffix > $@

.PHONY: backend
backend: $(BACKENDBUILT) \
    $(addprefix $(BLDSHAREDIR)/,cc cflags ldflags poststeps toolprefix)


# TOOLCHAIN
#############

SHAREDIRS := $(wildcard $(SHARE)/ocaml-unikraft-backend-*-$(TGTARCH))
ifeq ("$(strip $(SHAREDIRS))","")
SHAREDIRS := $(BLDSHAREDIR)
endif
CONFIGFILES := $(foreach d,$(SHAREDIRS),\
    $(addprefix $(d)/,cc cflags ldflags poststeps toolprefix))

TOOLCHAIN := gcc cc ar as ld nm objcopy objdump ranlib readelf strip
TOOLCHAIN := $(foreach tool,$(TOOLCHAIN),$(STDARCH)-unikraft-ocaml-$(tool))
BLDTOOLCHAIN := $(addprefix $(BLDBIN)/,$(TOOLCHAIN))
TOOLCHAIN := $(addprefix $(BIN)/,$(TOOLCHAIN))

$(BLDBIN)/$(STDARCH)-unikraft-ocaml-%: gen_toolchain_tool.sh $(CONFIGFILES) \
    | $(BLDBIN)
	./gen_toolchain_tool.sh $(TGTARCH) $(SHARE) $* > $@
	chmod +x $@

# Fetch the stdatomic.h header and its freestanding dependencies from the
# compiler
STDATOMIC_H := $(TOOLCHAINPKG)/include/stdatomic.h
BLDSTDATOMIC_H := $(BLDLIB)/$(STDATOMIC_H)
STDATOMIC_H := $(LIB)/$(STDATOMIC_H)
$(BLDSTDATOMIC_H): $(SHAREDIR)/cc | $(dir $(BLDSTDATOMIC_H))
	echo '#include <stdatomic.h>' \
	| $(file < $<) -ffreestanding -H -x c -E -o /dev/null - 2>&1 \
	| sed 's/^[^ ]* //' \
	| while read header; do cp "$$header" $(dir $@); done

.PHONY: toolchain
toolchain: $(BLDTOOLCHAIN) $(BLDSTDATOMIC_H)


# OCAML COMPILER
##################

# Extract sources from ocaml-src.tar.gz (if available, supporting the
# differences of options between various tar implementations to strip the first
# directory in the archive) or from the ocaml-src OPAM package and apply patches
# if there any in `patches/<OCaml version>/`
ocaml:
	mkdir -p $@
	if test -f ocaml-src.tar.gz; then \
	  if tar --version >/dev/null 2>&1; then \
	      tar -x -f ocaml-src.tar.gz -z -C $@ --strip-components=1; \
	    else tar -x -f ocaml-src.tar.gz -z -C $@ -s '/^[^\/]*\///'; \
	  fi ; \
	elif opam var ocaml-src:lib; then cp -R `opam var ocaml-src:lib` $@; \
	else echo Cannot find OCaml sources; false; \
	fi
	if test -d "patches/`head -n1 ocaml/VERSION`" ; then \
	  git apply --directory=$@ "patches/`head -n1 ocaml/VERSION`"/*; \
	fi

# We add $(BLDBIN) inconditionnally, even when using the installed toolchain: as
# the $(BLDBIN) directory should not be built, it will just be ignored
ocaml/Makefile.config: $(TOOLCHAIN) $(STDATOMIC_H) | ocaml
	cd ocaml && \
	  PATH="$$PWD/../$(BLDBIN):$$PATH" \
	  ./configure \
		--target=$(STDARCH)-unikraft-ocaml \
		--prefix=$(prefix)/lib/$(OCAMLPKG) \
		--disable-shared \
		--disable-ocamldoc \
		--without-zstd

$(OCAMLBUILT): ocaml/Makefile.config | _build
	PATH="$$PWD/$(BLDBIN):$$PATH" $(MAKE) -C ocaml cross.opt
	cd ocaml && ocamlrun tools/stripdebug ocamlc ocamlc.tmp
	cd ocaml && ocamlrun tools/stripdebug ocamlopt ocamlopt.tmp
	touch $@

OCAMLFIND_CONF := _build/unikraft_$(TGTARCH).conf
$(OCAMLFIND_CONF): gen_ocamlfind_conf.sh $(OCAMLBUILT)
	./gen_ocamlfind_conf.sh $(TGTARCH) $(prefix) > $@

.PHONY: compiler
compiler: $(OCAMLBUILT) $(OCAMLFIND_CONF) _build/empty


# OCAMLFIND TOOLCHAIN WITH A DEFAULT ARCHITECTURE
###################################################

_build/unikraft.conf: | _build
	./gen_ocamlfind_conf.sh default $(TGTARCH) $(prefix) > $@

# INSTALL
###########

$(BACKENDPKG).install: gen_backend_install.sh $(BACKENDBUILT) \
    $(addprefix $(SHAREDIR)/,cc cflags ldflags poststeps toolprefix)
	./gen_backend_install.sh $(PLAT)-$(TGTARCH) > $@

ocaml-unikraft-toolchain-$(TGTARCH).install: gen_toolchain_install.sh \
    $(BLDTOOLCHAIN) $(BLDSTDATOMIC_H)
	./gen_toolchain_install.sh $(TGTARCH) $(BLDTOOLCHAIN) > $@

OCAML_DOT_INSTALL_CHUNKS := $(addprefix _build/ocaml.install, .lib .libexec)
$(OCAML_DOT_INSTALL_CHUNKS): gen_ocaml_install.sh | _build ocaml/Makefile.config
	MAKE="$(MAKE)" bash gen_ocaml_install.sh _build/ocaml.install ocaml \
	    $(prefix)

ocaml-unikraft-$(TGTARCH).install: gen_dot_install.sh \
    $(OCAML_DOT_INSTALL_CHUNKS) $(OCAMLFIND_CONF) _build/empty
	./gen_dot_install.sh _build/ocaml.install $(TGTARCH) > $@

ocaml-unikraft-default-$(TGTARCH).install: _build/unikraft.conf
	printf 'lib_root: [\n  "%s" { "%s" }\n]\n' $< \
	  findlib.conf.d/unikraft.conf > $@


# MISC
########

_build/empty: | _build
	touch $@

# This rule doesn't use variables such as $(SHARE) etc. as we want to create
# the directories only in _build: if SHARE is explicitly set to a different
# (installation) directory, we should really not try to create it
# The use case is building only one OPAM package using already installed OPAM
# packages
ALLDIRS := $(BACKENDPKG) $(OCAMLPKG) $(TOOLCHAINPKG) $(TOOLCHAINPKG)/include
ALLDIRS := bin lib $(addprefix lib/,$(ALLDIRS)) share share/$(BACKENDPKG)
ALLDIRS := _build $(addprefix _build/,$(ALLDIRS))
ALLDIRS := $(ALLDIRS) $(addsuffix /,$(ALLDIRS))
$(ALLDIRS):
	mkdir -p $@

_build/lib/unikraft: | _build/lib
	$(SYMLINK) $(UNIKRAFT) $@

.PHONY: clean
clean:
	rm -rf _build
	if [ -d ocaml ] ; then $(MAKE) -C ocaml clean ; fi

.PHONY: distclean
distclean: clean
# Don't remove the ocaml directory itself, to play nicer with
# development in there
	if [ -d ocaml ] ; then $(MAKE) -C ocaml distclean ; fi
