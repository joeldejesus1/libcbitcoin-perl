#use 5.014002;
use strict;
use warnings;
use ExtUtils::MakeMaker;


WriteMakefile(
	    'TYPEMAPS' => []
	    ,'NAME' => 'CBitcoin'
	     ,'LIBS' => [ ' -lcrypto -lccoin -lgmp ' ]
		,'VERSION' => '0.1'

		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'lib/CBitcoin.pm'
		#,'ABSTRACT_FROM'       => 'lib/CBitcoin.pm'
		#,'MAGICXS' => 1
		,'OBJECT'              => q/$(O_FILES)/
		#,'OBJECT' => 'lib/CBitcoin/CBHD.so'
		#, 'XS'      => {
       # 	"lib/CBitcoin/CBHD.xs" => "lib/CBitcoin/CBHD.c",
    	#}
		#,'MYEXTLIB' => '/usr/lib/libcbitcoin.so.1'
	,($ExtUtils::MakeMaker::VERSION >= 6.3002
	      ? ('LICENSE'=> 'gpl_2')
	      : ())
	,'PL_FILES'            => {}
	,'PREREQ_PM' => {
		'Test::More' => 0,
	}
	,'EXE_FILES' => [
		'scripts/spv'	
	]
	#,'LDDLFLAGS' => ' -fstack-protector '
	#,'LDFLAGS' => ' -fstack-protector '
	,'MAKEFILE_OLD' => ''
	,'dist'                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', }
	,'clean'               => { FILES => 'libcbitcoin-perl*' }
);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile {
#	return qq{ };

	return qq{
all ::
	(cd blib/arch/auto/CBitcoin/ && ( [ -d CBHD ] || mkdir CBHD ) && ([ -e CBHD/CBHD.so ] || ln -s ../CBitcoin.so CBHD/CBHD.so ) )
	(cd blib/arch/auto/CBitcoin/ && ( [ -d Script ] || mkdir Script ) && ( [ -e Script/Script.so ] || ln -s ../CBitcoin.so Script/Script.so ) )
#	(cd blib/arch/auto/CBitcoin/ && ( [ -d TransactionInput ] || mkdir TransactionInput ) && ( [ -e TransactionInput/TransactionInput.so ] || ln -s ../CBitcoin.so TransactionInput/TransactionInput.so ) )
#	(cd blib/arch/auto/CBitcoin/ && ( [ -d TransactionOutput ] || mkdir TransactionOutput ) && ( [ -e TransactionOutput/TransactionOutput.so ] || ln -s ../CBitcoin.so TransactionOutput/TransactionOutput.so ) )
#	(cd blib/arch/auto/CBitcoin/ && ( [ -d Transaction ] || mkdir Transaction ) && ( [ -e Transaction/Transaction.so ] || ln -s ../CBitcoin.so Transaction/Transaction.so ) )
##	(cd blib/arch/auto/CBitcoin/ && ( [ -d Message ] || mkdir Message ) && ( [ -e Message/Message.so ] || ln -s ../CBitcoin.so Message/Message.so ) )
#	(cd blib/arch/auto/CBitcoin/ && ( [ -d Block ] || mkdir Block ) && ( [ -e Block/Block.so ] || ln -s ../CBitcoin.so Block/Block.so ) )

};

}

__END__


    ZFSonAWS is a program that automates backing up zfs snapshots onto AWS's S3.
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
