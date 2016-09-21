package CBitcoin;

#use 5.014002;
use strict;
use warnings;

=pod

---+ Constants

   * [[https://github.com/bitcoin/bitcoin/blob/e9d76a161d30ee3081acf93d70a9ae668a9d6ed1/src/version.h][version]]
   * [[https://en.bitcoin.it/wiki/Protocol_documentation#sendheaders][constants]]
=cut

use constant {
	MAINNET => 0xD9B4BEF9
	,TESTNET => 0xDAB5BFFA
	,TESTNET3 => 0x0709110B
	,NAMECOIN => 0xFEB4BEF9
	
	
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




=head1 NAME

CBitcoin - The great new CBitcoin!

=head1 VERSION

Version 0.01

=cut

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::VERSION = '0.1';

DynaLoader::bootstrap CBitcoin $CBitcoin::VERSION;

@CBitcoin::EXPORT = ('MAINNET', 'TESTNET', 'TESTNET3');
@CBitcoin::EXPORT_OK = ( );
%CBitcoin::EXPORT_TAGS = (  );

=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=item hello

just a place holder.

=cut

sub hello {
	return "hello!";
}


our $network_bytes = 0xD9B4BEF9;


=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT


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

=cut

1; # End of CBitcoin
