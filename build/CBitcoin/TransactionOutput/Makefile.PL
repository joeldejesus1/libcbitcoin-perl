use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;


foreach my $package ('CBitcoin::TransactionOutput'){
	WriteMakefile(
	  'TYPEMAPS' => [],
	  'NAME' => $package,
	#  'INC' => '../../library/include',
	   'INC' => '~/Workspace/cbitcoin/library/include',
	  'LIBS' => ['-lcbitcoin.2.0',
					'-lcbitcoin-network.2.0',
					'-lcbitcoin-storage.2.0',
					'-lcbitcoin-threads.2.0',
					'-lpthread',
					'-lcbitcoin-logging.2.0',
					'-lcbitcoin-crypto.2.0',
					'-lcrypto',
					'-lcbitcoin.2.0',
					'-lcbitcoin-file-ec.2.0',
					'-lcbitcoin-rand.2.0'
		]
		,'MYEXTLIB' => '/usr/local/lib/libcbitcoin.2.0.so /usr/local/lib/libcbitcoin-file-no-ec.2.0.so /usr/local/lib/libcbitcoin-rand.2.0.so /usr/local/lib/libcbitcoin-threads.2.0.so /usr/local/lib/libcbitcoin-network.2.0.so /usr/local/lib/libcbitcoin-file-ec.2.0.so /usr/local/lib/libcbitcoin-storage.2.0.so /usr/local/lib/libcbitcoin-crypto.2.0.so /usr/local/lib/libcbitcoin-logging.2.0.so '
		,'VERSION' => '0.01'
		
		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'lib/CBitcoin/TransactionOutput.pm'
		,'ABSTRACT_FROM'       => 'lib/CBitcoin/TransactionOutput.pm'
		,'OBJECT'              => q/$(O_FILES)/
#		,'XS'      => {
#			"lib/CBitcoin/TransactionOutput.xs" => "lib/CBitcoin/TransactionOutput.c"
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
		,'dist'                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', }
		,'clean'               => { FILES => 'libperl-cbitcoin-*' }
	);
}


# Remove the Makefile dependency. Causes problems on a few systems.
#sub MY::makefile { '' }
