#!/bin/bash

PERLBUILDDIR=.
PERLEXEC=/usr/bin/perl


find ${PERLBUILDDIR} -name 'Makefile.PL'  | while read line; 
	do echo "running Makefile.PL $line";
	CURDIR=$(pwd)
	echo "Starting from $CURDIR"
	cd $(dirname $line)
	echo "Compiling debian $(pwd)"
	dh_make -e dejesus.joel@e-flamingo.jp --createorig -s
	debuild -uc
	cd $CURDIR 
done;
