#
# @(#)Makefile TCSG5 tools
# 
# install the scripts
#
all: install

FILES=tcsg5-apitool districert.sh listcerts.sh nik-acme-certupdate probecert
DOCFILES=README.txt

install:
	cp -p $(FILES) ~/bin/
	scp -p $(FILES) $(DOCFILES) davidg@software.nikhef.nl:/project/srv/www/site/software/html/experimental/tcstools/tcsg5/

