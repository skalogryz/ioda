PPC=/usr/bin/ppc386
TAR=/bin/tar
RM=/bin/rm -f
INSTALL=/usr/bin/install

TARGETS=joda jodacgi jodad checkdb libjodafulltext.so

JODAUNITS=bayerbaum.ppu sbayerbaum.ppu \
	idlist.ppu occtable3.ppu filerefs.ppu \
	syntaxparser.ppu \
	dirscanner.ppu logbook.ppu configreader.ppu \
	volltext2.ppu ionet2.ppu regexpro.ppu

prefix=$(DESTDIR)/usr
bindir=$(prefix)/bin
libdir=$(prefix)/lib
includedir=$(prefix)/include

all: $(TARGETS)

%.ppu: %.pas
	$(PPC) $<

joda: $(JODAUNITS) joda.pas
	$(PPC) joda.pas

jodacgi: $(JODAUNITS) jodacgi.pas
	$(PPC) jodacgi.pas

jodad: $(JODAUNITS) jodad.pas
	$(PPC) jodad.pas

checkdb: $(JODAUNITS) checkdb.pas
	$(PPC) checkdb.pas

libjodafulltext.so: $(JODAUNITS) jodafulltext.pas
	$(PPC) jodafulltext.pas

clean:
	$(RM) *.o *.ppu ppas.sh link.res jodafulltext.def $(TARGETS)

install: $(TARGETS)
	$(INSTALL) -d $(bindir)
	$(INSTALL) -d $(libdir)
	$(INSTALL) -d $(includedir)
	$(INSTALL) -m 755 joda jodacgi jodad $(bindir)
	$(INSTALL) -m 644 libjodafulltext.so $(libdir)
	$(INSTALL) -m 644 jodafulltext.h     $(includedir)

