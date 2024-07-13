## For some reason, this makefile script is not working for me
## resorted to directly running the steps as listed in the onenote
## The problematic line is probably the line 1 in config.mk as it is setting properties for all g files, but toolchain is modern gcc>  export CFLAGS = -std=c99 -g
TOOLCHAIN_PREFIX = $(abspath toolchain/$(TARGET))
export PATH := $(TOOLCHAIN_PREFIX)/bin:$(PATH)

toolchain: toolchain_binutils toolchain_gcc

BINUTILS_SRC = toolchain/binutils-$(BINUTILS_VERSION)
BINUTILS_BUILD = toolchain/binutils-build-$(BINUTILS_VERSION)

toolchain_binutils: $(BINUTILS_SRC).tar.gz
	# cd toolchain && tar -xzf binutils-$(BINUTILS_VERSION).tar.gz
	mkdir $(BINUTILS_BUILD)
	cd $(BINUTILS_BUILD) && ../binutils-$(BINUTILS_VERSION)/configure --prefix="$(TOOLCHAIN_PREFIX)" --target=$(TARGET)	--with-sysroot --disable-nls --disable-werror
	cd $(BINUTILS_BUILD) && $(MAKE) -j4
	cd $(BINUTILS_BUILD) && $(MAKE) install

$(BINUTILS_SRC).tar.gz:
	mkdir -p toolchain
	cd toolchain && wget $(BINUTILS_URL)


GCC_SRC = toolchain/gcc-$(GCC_VERSION)
GCC_BUILD = toolchain/gcc-build-$(GCC_VERSION)

toolchain_gcc: toolchain_binutils $(GCC_SRC).tar.gz
	cd toolchain && tar -xzf gcc-$(GCC_VERSION).tar.gz
	mkdir $(GCC_BUILD)
	cd $(GCC_BUILD) && ../gcc-$(GCC_VERSION)/configure \
		--prefix="$(TOOLCHAIN_PREFIX)" 	\
		--target=$(TARGET)				\
		--disable-nls					\
		--enable-languages=c,c++		\
		--without-headers
	$(MAKE) -j8 -C $(GCC_BUILD) all-gcc all-target-libgcc
	$(MAKE) -C $(GCC_BUILD) install-gcc install-target-libgcc

$(GCC_SRC).tar.gz:
	mkdir -p toolchain
	cd toolchain && wget $(GCC_URL)

#
# Clean
#
clean-toolchain:
	rm -rf $(GCC_BUILD) $(GCC_SRC) $(BINUTILS_BUILD) $(BINUTILS_SRC)

clean-toolchain-all:
	rm -rf toolchain/*

.PHONY:  toolchain toolchain_binutils toolchain_gcc clean-toolchain clean-toolchain-all