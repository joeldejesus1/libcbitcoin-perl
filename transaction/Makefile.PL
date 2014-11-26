use 5.014002;
use strict;
use warnings;
use ExtUtils::MakeMaker;


foreach my $package ('CBitcoin::Transaction'){
	WriteMakefile(
	  'TYPEMAPS' => [],
	  'NAME' => $package,
	  'LIBS' => [' -lcbitcoin -lcrypto ' ]
		,'VERSION' => '0.01'
		
		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'lib/CBitcoin/Transaction.pm'
		,'ABSTRACT_FROM'       => 'lib/CBitcoin/Transaction.pm'
		,'OBJECT'              => q/$(O_FILES)/
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
