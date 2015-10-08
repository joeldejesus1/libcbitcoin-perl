# libcbitcoin-perl

There is one debian package and several perl modules encapsulated in this repository. The main module is CBitcoin.  
This module contains no subroutines.  Instead, it is used as a placeholder for the XS modules.  All of the XS modules for the other perl modules are chained to CBitcoin.xs. 
Unfortunately, in some situations (unknown to the author), require symlinking the shared library CBitcoin.so into where Dynaloader (via bootloader) automatically looks for shared libraries of the perl module being run. 
For example, bootloader looks for the XS binary in auto/CBitcoin/CBHD/CBHD.so when running CBHD::xs_sub.  
So, we have to symlink auto/CBitcoin/CBitcoin.so to auto/CBitcoin/CBHD/CBHD.so.

To create Hierarchial Deterministic keys, see CBitcoin::CBHD.  
To create scripts, see CBitcoin::Script. To create transactions, see CBitcoin::Transaction, CBitcoin::TransactionInput and CBitcoin::TransactionOutput.

## DEBIAN INSTALLATION

To compile a debian package, first install libcbitcoin0, which is https://github.com/favioflamingo/cbitcoin.  
Once you compile and install the cbitcoin source package, go into the main directory and tyoe:
```bash
    dh_make -p libcbitcoin-perl_0.01 --createorig -l
    debuild -uc
```

## INSTALLATION

To install this module, run the following commands:
```bash
	perl Makefile.PL
	make
	make test
	make install
```

## SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.
```bash
    perldoc CBitcoin
``` 
    or
```bash
    perldoc CBitcoin::CBHD
```

## LICENSE AND COPYRIGHT

Copyright (C) 2014 Joel De Jesus

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

