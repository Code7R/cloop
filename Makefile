#!/usr/bin/make

MACHINE=$(shell uname -m)
ifndef KERNEL_DIR
KERNEL_DIR:=/lib/modules/`uname -r`/build
endif

file_exist=$(shell test -f $(1) && echo yes || echo no)

# test for 2.6 or 2.4 kernel
ifeq ($(call file_exist,$(KERNEL_DIR)/Rules.make), yes)
PATCHLEVEL:=4
else
PATCHLEVEL:=6
endif

ifdef APPSONLY
CFLAGS:=-Wall -Wstrict-prototypes -Wno-trigraphs -O2 -s -I. -fno-strict-aliasing -fno-common -fomit-frame-pointer 
endif

KERNOBJ:=cloop.o

# Name of module
ifeq ($(PATCHLEVEL),6)
MODULE:=cloop.ko
else
MODULE:=cloop.o
endif

ALL_TARGETS = create_compressed_fs extract_compressed_fs
ifndef APPSONLY
ALL_TARGETS += $(MODULE)
endif

all: $(ALL_TARGETS)

module: $(MODULE)

utils: create_compressed_fs extract_compressed_fs

# For Kernel >= 2.6, we now use the "recommended" way to build kernel modules
obj-m := cloop.o
# cloop-objs := cloop.o

$(MODULE): cloop.c cloop.h
	@echo "Building for Kernel Patchlevel $(PATCHLEVEL)"
	$(MAKE) modules -C $(KERNEL_DIR) M=$(CURDIR)

create_compressed_fs: advancecomp-1.15/advfs
	ln -f $< $@

advancecomp-1.15/advfs:
	( cd advancecomp-1.15 ; ./configure && $(MAKE) advfs )

extract_compressed_fs: extract_compressed_fs.c
	$(CC) -Wall -O2 $(CFLAGS) $(LDFLAGS) -o $@ $< -lz

cloop_suspend: cloop_suspend.o
	$(CC) -Wall -O2 -s -o $@ $<

clean:
	rm -rf create_compressed_fs extract_compressed_fs zoom *.o *.ko Module.symvers .cloop* .compressed_loop.* .tmp* modules.order cloop.mod.c
	[ -f advancecomp-1.15/Makefile ] && $(MAKE) -C advancecomp-1.15 distclean || true

dist: clean
	cd .. ; \
	tar -cf - cloop/{Makefile,*.[ch],CHANGELOG,README} | \
	bzip2 -9 > $(HOME)/redhat/SOURCES/cloop.tar.bz2



# some convenience code borrowed from apt-cacher-ng
#
# cloop specific part
PKGNAME=cloop
# no-op, just make sure the files are there
fixversion: VERSION
doc: ChangeLog

VERSION=$(shell cat VERSION)
TAGVERSION=$(subst rc,_rc,$(subst pre,_pre,$(VERSION)))
DISTNAME=$(PKGNAME)-$(VERSION)
DEBSRCNAME=$(PKGNAME)_$(shell echo $(VERSION) | sed -e "s,pre,~pre,;s,rc,~rc,;").orig.tar.xz


tarball: fixversion doc notdebianbranch nosametarball
	# diff-index is buggy and reports false positives... trying to enforce it
	git update-index --refresh || git commit -a
	git diff-index --quiet HEAD || git commit -a
	git archive --prefix $(DISTNAME)/ HEAD | xz -9 > ../$(DISTNAME).tar.xz
	test -e /etc/debian_version && ln -f ../$(DISTNAME).tar.xz ../$(DEBSRCNAME) || true
	test -e ../tarballs && ln -f ../$(DISTNAME).tar.xz ../tarballs/$(DEBSRCNAME) || true
	test -e ../build-area && ln -f ../$(DISTNAME).tar.xz ../build-area/$(DEBSRCNAME) || true

tarball-remove:
	rm -f ../$(DISTNAME).tar.xz ../tarballs/$(DEBSRCNAME) ../$(DEBSRCNAME) ../build-area/$(DEBSRCNAME)

release: noremainingwork tarball
	git tag upstream/$(TAGVERSION)

unrelease: tarball-remove
	git tag -d upstream/$(TAGVERSION)

noremainingwork:
	test ! -e TODO.next # the quick reminder for the next release should be empty

notdebianbranch:
	test ! -f debian/rules # make sure it is not run from the wrong branch

nosametarball:
	test ! -f ../$(DISTNAME).tar.xz # make sure not to overwrite existing tarball
	test ! -f ../tarballs/$(DEBSRCNAME)
