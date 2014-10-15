#!/bin/sh

ARCH=amd64

set -e

cd CBHD

make clean && perl coinx2.pl && cp old-config/* ./ && perl Makefile.PL && make
DEBTARDIR=../debs/libperl-cbitcoin-cbhd_0.01
DEBTARDIRPERL=${DEBTARDIR}/usr/lib/perl5
[ -d ${DEBTARDIR}/DEBIAN ] || mkdir -p ${DEBTARDIR}/DEBIAN 
[ -d ${DEBTARDIR}/usr/lib/perl5/auto ] || mkdir -p ${DEBTARDIR}/usr/lib/perl5/auto 
cp -r blib/arch/auto/* ${DEBTARDIRPERL}/auto/
cp -r blib/lib/* ${DEBTARDIRPERL}/
find ${DEBTARDIRPERL}/ -name '*.exists' -exec rm {} \;
find ${DEBTARDIRPERL}/ -name '*coinx2.pl' -exec rm {} \;

