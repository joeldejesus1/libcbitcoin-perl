# libcbitcoin-perl

There is one debian package and several perl modules encapsulated in this repository. The main module is CBitcoin.  
This module contains no subroutines.  Instead, it is used as a placeholder for the XS modules.  All of the XS modules for the other perl modules are chained to CBitcoin.xs. 
Unfortunately, in some situations (unknown to the author), require symlinking the shared library CBitcoin.so into where Dynaloader (via bootloader) automatically looks for shared libraries of the perl module being run. 
For example, bootloader looks for the XS binary in auto/CBitcoin/CBHD/CBHD.so when running CBHD::xs_sub.  
So, we have to symlink auto/CBitcoin/CBitcoin.so to auto/CBitcoin/CBHD/CBHD.so.

To create Hierarchial Deterministic keys, see CBitcoin::CBHD.  
To create scripts, see CBitcoin::Script. To create transactions, see CBitcoin::Transaction, CBitcoin::TransactionInput and CBitcoin::TransactionOutput.

To see how an spv client works, check out the t/spv.t.no script.  It contains an example of how to implement an spv client in perl.  Though, this section is work in progress.

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

    CBitcoin perl modules is a wrapper for the CBitcoin library written by Matthew Mitchell.
    Copyright (C) 2015  Joel De Jesus

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

