#!/usr/bin/env bash

ARCH=amd64

set -e

CUSER=$(whoami)

CBMODULE=CBHD
CBDIR=/home/joeldejesus/Workspace/cbitcoin-perl/${CBMODULE}
MODNAME=libperl-cbitcoin-cbhd
MODVER="0.01"


echo "heading into the $CBDIR directory"
cd ${CBDIR}

echo "compiling"
[ -f ${CBDIR}/Makefile ] && make clean
perl coinx2.pl
cp -r old-config/* ./ && rm -r debian
perl Makefile.PL
make
DEBTARDIR=../debs/${MODNAME}-${MODVER}
DEBTARDIRPERL=${DEBTARDIR}/usr/lib/perl5

echo "cleaning out old debian tar directory"
[ -d ${DEBTARDIR} ] && sudo rm -r ${DEBTARDIR}

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


cp -r ${CBDIR}/old-config/debian ${DEBTARDIR}/debian

echo "taring files $(pwd) "
echo "of ${DEBTARDIR}"
cd ${DEBTARDIR}
tar zcf ${CBDIR}/../debs/${MODNAME}_${MODVER}.orig.tar.gz *

cd ${CBDIR}/../debs/${MODNAME}-${MODVER}

echo "creating deb package and signing it"
dpkg-buildpackage -rfakeroot -k
