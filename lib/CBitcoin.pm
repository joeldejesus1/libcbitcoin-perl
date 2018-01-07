package CBitcoin;

#use utf8;
use strict;
use warnings;
use File::ShareDir;

=head1 NAME

CBitcoin - A wrapper for the Picocoin C Library

=head1 SEE INSTEAD?

The module L<CBitcoin> serves as a bootstrapping point for other modules to compile.
Also, it is used to set the network to do computations off of (MAINNET, TESTNET, etc).

THe documentation is still work in progress.  More complete documentation is available at https://github.com/favioflamingo/libcbitcoin-perl and https://github.com/favioflamingo/picocoin

The picocoin library needs to be compiled and installed before this module can be used.

=head1 VERSION

Version 0.6

=cut


=item Constants

   * [[https://github.com/bitcoin/bitcoin/blob/e9d76a161d30ee3081acf93d70a9ae668a9d6ed1/src/version.h][version]]
   * [[https://en.bitcoin.it/wiki/Protocol_documentation#sendheaders][constants]]
   
=cut

use constant {
	MAINNET => 0xD9B4BEF9
	,TESTNET => 0xDAB5BFFA
	,TESTNET3 => 0x0709110B
	,NAMECOIN => 0xFEB4BEF9
	,REGNET => 0xFABFB5DA
	
	,CHAIN_LEGACY => 0
	,CHAIN_UAHF => 1
	
	,BIP32_MAINNET_PUBLIC => 0x0488B21E
	,BIP32_MAINNET_PRIVATE => 0x0488ADE4
	,BIP32_TESTNET_PUBLIC => 0x043587CF
	,BIP32_TESTNET_PRIVATE => 0x04358394
	,BIP32_REGNET_PUBLIC => 0x043587CF
	,BIP32_REGNET_PRIVATE => 0x04358394
	
	,SPV_PROTOCOL_VERSION => 70014
	,SPV_INIT_PROTO_VERSION => 209
	,SPV_GETHEADERS_VERSION => 31800
	,SPV_MIN_PEER_PROTO_VERSION => 31800
	,SPV_CADDR_TIME_VERSION => 31402
	,SPV_BIP0031_VERSION => 70014
	,SPV_MEMPOOL_GD_VERSION => 70014
	,SPV_NO_BLOOM_VERSION => 70011
	,SPV_BIP0031_VERSION => 60000
	,SPV_SENDHEADERS_VERSION  => 70012
	,SPV_FEEFILTER_VERSION => 70013
	,SPV_SHORT_IDS_BLOCKS_VERSION => 70014
};


require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::VERSION = '0.6';

DynaLoader::bootstrap CBitcoin $CBitcoin::VERSION;

@CBitcoin::EXPORT = ('MAINNET', 'TESTNET', 'TESTNET3','REGNET');
@CBitcoin::EXPORT_OK = ( );
%CBitcoin::EXPORT_TAGS = (  );

=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking


=item network_bytes

Set network bytes with the $network_bytes global variable.

=cut

our $network_bytes = MAINNET;
our $chain = CHAIN_LEGACY;



sub module_directory {
	
	
	return  File::ShareDir::module_dir('CBitcoin');
}

=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.net> >>



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT


    CBitcoin perl modules is a wrapper for the Picocoin library written by Jeff Garzik.
    Copyright (C) 2015-2017  Joel De Jesus

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

=cut

1; # End of CBitcoin
