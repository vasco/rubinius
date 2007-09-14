
include shotgun/config.mk

all: shotgun/rubinius.bin exts

shotgun/rubinius.bin:
	cd shotgun; $(MAKE) rubinius

exts: shotgun/rubinius.bin
	./shotgun/rubinius compile -foutput=lib/ext/syck/rbxext lib/ext/syck/rbxext.c -Ilib/ext/syck lib/ext/syck/*.c

install:
	cd shotgun; $(MAKE) install
	mkdir -p $(RBAPATH)
	mkdir -p $(CODEPATH)
	cp runtime/*.rba runtime/*.rbc $(RBAPATH)/
	mkdir -p $(CODEPATH)/bin
	cp -r lib/* $(CODEPATH)/
	for rb in $(CODEPATH)/*.rb ; do $(BINPATH)/rbx compile $$rb; done	
	for rb in $(CODEPATH)/**/*.rb ; do $(BINPATH)/rbx compile $$rb; done	

clean:
	cd shotgun; $(MAKE) clean

.PHONY: all install clean
