ifdef VERBOSE
PPC=/usr/bin/ppc386 -vewnih
else
PPC=/usr/bin/ppc386
endif
TAR=/bin/tar
RM=/bin/rm -f
INSTALL=/usr/bin/install

TARGETS=joda jodad libjodafulltext.so checkdb checkbtree convert05 jodacgi

JODAUNITS=regexpr.ppu md5.ppu unicode.ppu jstreams.ppu jstrings.ppu \
	btreeflex.ppu idlist.ppu occtable.ppu filerefs.ppu \
	syntaxparser.ppu globs.ppu \
	dirscanner.ppu logbook.ppu configreader.ppu \
	ionet.ppu hitlist.ppu \
	volltext.ppu

prefix=$(DESTDIR)/usr
bindir=$(prefix)/bin
libdir=$(prefix)/lib
includedir=$(prefix)/include

all: $(TARGETS)

%.ppu: %.pas
	$(PPC) $<

# special handling for the delphi based TRegExpr class
regexpr.ppu: regexpr.pas
	$(PPC) -Sd $<

joda: $(JODAUNITS) joda.pas
	$(PPC) joda.pas

jodacgi: $(JODAUNITS) jodacgi.pas
	$(PPC) jodacgi.pas

jodad: $(JODAUNITS) jodad.pas
	$(PPC) jodad.pas

checkdb: $(JODAUNITS) checkdb.pas
	$(PPC) checkdb.pas

checkbtree: $(JODAUNITS) checkbtree.pas
	$(PPC) checkbtree.pas

convert05: $(JODAUNITS) convert05.pas
	$(PPC) convert05.pas

libjodafulltext.so: $(JODAUNITS) jodafulltext.pas
	$(PPC) jodafulltext.pas

clean:
	$(RM) *.o *.ppu ppas.sh link.res jodafulltext.def $(TARGETS)

install: $(TARGETS)
	$(INSTALL) -d $(bindir)
	$(INSTALL) -d $(libdir)
	$(INSTALL) -d $(includedir)
	$(INSTALL) -m 755 joda jodad $(bindir)
	$(INSTALL) -m 644 libjodafulltext.so $(libdir)
	$(INSTALL) -m 644 jodafulltext.h     $(includedir)

