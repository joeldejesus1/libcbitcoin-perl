use 5.014002;
use strict;
use warnings;
use ExtUtils::MakeMaker;


foreach my $package ('CBitcoin::CBHD'){
	WriteMakefile(
	  'TYPEMAPS' => [],
	  'NAME' => $package,
	#  'INC' => '../../library/include',
	     'LIBS' => [ ' -lpthread -lcrypto -lcbitcoin ' ],
		,'VERSION' => '0.01'
#		,'MYEXTLIB' => '/usr/lib/libcbitcoin.so'
		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'lib/CBitcoin/CBHD.pm'
		,'ABSTRACT_FROM'       => 'lib/CBitcoin/CBHD.pm'
		,'OBJECT'              => q/$(O_FILES)/
#		,'XS'      => {
#			"lib/CBitcoin/CBHD.xs" => "lib/CBitcoin/CBHD.c"
#			,"lib/CBitcoin/Transaction.xs" => "lib/CBitcoin/Transaction.c"
#			,"lib/CBitcoin/TransactionInput.xs" => "lib/CBitcoin/TransactionInput.c"
#			,"lib/CBitcoin/TransactionOutput.xs" => "lib/CBitcoin/TransactionOutput.c"
#			,"lib/CBitcoin/Script.xs" => "lib/CBitcoin/Script.c"
#		}
		,($ExtUtils::MakeMaker::VERSION >= 6.3002
		      ? ('LICENSE'=> 'gpl_2')
		      : ())
		,'PL_FILES'            => {}
		,'PREREQ_PM' => {
			'Test::More' => 0,
		}
		,'MAKEFILE_OLD' => ''
		,'dist'                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', }
		,'clean'               => { FILES => 'libperl-cbitcoin-*' }
	);
}


# Remove the Makefile dependency. Causes problems on a few systems.
#sub MY::makefile { '' }
