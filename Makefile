# vim:ts=3
RENDERTMP = $(PWD)/tmp
CHUNK_QUIET = 1
ROOT_ID =
SHELL = /bin/bash

ifdef V
  Q =
else
  Q = @
endif

ARCH = glibc
REV = systemd
BASEDIR         ?= $(PWD)/public/systemd
PDF_OUTPUT      ?= LFS-TINY-BOOK.pdf
NOCHUNKS_OUTPUT ?= LFS-TINY-BOOK.html
DUMPDIR         ?= $(PWD)/lfs-systemd-commands
THEME       ?= purple
THEME_PATH  ?= stylesheets/lfs-xsl

help:
	@echo ""
	@echo "make <parameters> <targets>"
	@echo ""
	@echo "Parameters:"
	@echo ""
	@echo "  REV=<rev>            Build variation of book"
	@echo "                       Valid values for REV are:"
	@echo "                       * systemd - Build book for systemd"
	@echo "                       * sysv    - Build book for SysV"
	@echo "                       Defaults to 'systemd'"
	@echo ""
	@echo "  BASEDIR=<dir>        Put the output in directory <dir>."
	@echo "                       Defaults to"
	@echo "                       '$(HTML_ROOT)/slfs' if REV=systemd (or unset)"
	@echo "                       or to"
	@echo "                       '$(HTML_ROOT)/slfs-sysv' if REV=sysv"
	@echo ""
	@echo "  V=<val>              If <val> is a non-empty value, all"
	@echo "                       steps to produce the output is shown."
	@echo "                       Default is unset."
	@echo "  THEME_PATH=<path>    Sets the path of themes (CSS files)."
	@echo "                       'stylesheets/lfs-xsl' is the default."
	@echo ""
	@echo "  THEME=<theme>        Sets the theme of the book, ie."
	@echo "                       light/dark/dynamic."
	@echo "                       The dynamic theme is the default."


book: validate profile-html
	@echo "Generating chunked XHTML files at $(BASEDIR)/ ..."
	$(Q)xsltproc --nonet                          \
      --stringparam chunk.quietly $(CHUNK_QUIET) \
      --stringparam rootid "$(ROOT_ID)"          \
      --stringparam base.dir $(BASEDIR)/         \
      stylesheets/lfs-chunked.xsl                \
      $(RENDERTMP)/lfs-html.xml

	@echo "Copying CSS code and images..."
	$(Q)mkdir -p $(BASEDIR)/stylesheets
	$(Q)cp $(THEME_PATH)/$(THEME).lfs.css $(BASEDIR)/stylesheets/lfs.css
	$(Q)cp stylesheets/lfs-xsl/lfs-print.css $(BASEDIR)/stylesheets
	$(Q)sed -e 's|../stylesheet|stylesheet|' \
           -i $(BASEDIR)/index.html

	$(Q)mkdir -p $(BASEDIR)/images
	$(Q)cp images/*.png $(BASEDIR)/images

	@echo "Running Tidy and obfuscate.sh..."
	$(Q)for filename in `find $(BASEDIR) -name "*.html"`; do \
         tidy -config tidy.conf $$filename;           \
         /bin/bash obfuscate.sh $$filename;           \
         sed -e "s|text/html|application/xhtml+xml|g" \
             -i $$filename;                           \
       done

tmpdir:
	@echo "Creating and cleaning $(RENDERTMP)"
	$(Q)mkdir -p $(RENDERTMP)
	$(Q)rm -f $(RENDERTMP)/lfs*.xml
	$(Q)rm -f $(RENDERTMP)/*wget*
	$(Q)rm -f $(RENDERTMP)/*sha256sum*
	$(Q)rm -f $(RENDERTMP)/*pdf.fo

validate: tmpdir
	@echo "Adjusting for arch $(ARCH) revision $(REV)..."
	$(Q)xsltproc --nonet                               \
                --xinclude                            \
                --stringparam profile.revision $(REV) \
                --stringparam profile.arch $(ARCH)    \
                --output $(RENDERTMP)/lfs-html2.xml   \
                stylesheets/lfs-xsl/profile.xsl       \
                index.xml

	@echo "Validating the book..."
	$(Q)xmllint --nonet                            \
               --encode UTF-8                     \
               --postvalid                        \
               --output $(RENDERTMP)/lfs-full.xml \
               $(RENDERTMP)/lfs-html2.xml

	@echo "Validation complete."

profile-html:
	@echo "Generating profiled XML for XHTML..."
	$(Q)xsltproc --nonet                              \
                --stringparam profile.condition html \
                --output $(RENDERTMP)/lfs-html.xml   \
                stylesheets/lfs-xsl/profile.xsl      \
                $(RENDERTMP)/lfs-full.xml


dump-commands: validate
	@echo "Dumping book commands..."

	$(Q)rm -rf $(DUMPDIR)

	$(Q)xsltproc --output $(DUMPDIR)/          \
                stylesheets/dump-commands.xsl \
                $(RENDERTMP)/lfs-full.xml
	@echo "Dumping book commands complete in $(DUMPDIR)"

all: book dump-commands

.PHONY : all book dump-commands profile-html tmpdir validate version help
