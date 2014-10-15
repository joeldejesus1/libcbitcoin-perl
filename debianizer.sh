#!/bin/sh

ARCH=amd64

set -e

CUSER=$(whoami)

cd CBHD

echo "compiling"
make clean && perl coinx2.pl && cp old-config/* ./ && perl Makefile.PL && make
DEBTARDIR=../debs/libperl-cbitcoin-cbhd_0.01
DEBTARDIRPERL=${DEBTARDIR}/usr/lib/perl5
echo "cleaning out old debian tar directory"
sudo rm -r ${DEBTARDIR}

echo "making directories"
#[ -d ${DEBTARDIR}/DEBIAN ] || mkdir -p ${DEBTARDIR}/DEBIAN 
[ -d ${DEBTARDIR}/usr/lib/perl5/auto ] || mkdir -p ${DEBTARDIR}/usr/lib/perl5/auto 
echo "copying binaries"
sudo cp -r blib/arch/auto/* ${DEBTARDIRPERL}/auto/
echo "copying perl libs"
sudo cp -r blib/lib/* ${DEBTARDIRPERL}/
# we had to sudo copy because of the 644 permissions on the lib files


echo "deleting cruft"
sudo find ${DEBTARDIRPERL}/ -name '*.exists' -exec rm {} \;
sudo find ${DEBTARDIRPERL}/ -name '*coinx2.pl' -exec rm {} \;

sudo chown -R $CUSER:$CUSER ${DEBTARDIR}
