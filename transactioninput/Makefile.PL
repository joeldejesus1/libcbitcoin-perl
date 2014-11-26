use 5.014002;
use strict;
use warnings;
use ExtUtils::MakeMaker;


WriteMakefile(
	  'TYPEMAPS' => [],
	  'NAME' => 'CBitcoin::TransactionInput',
	     'LIBS' => [ ' -lcrypto -lcbitcoin ' ],
		,'VERSION' => '0.01'

		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'TransactionInput.pm'
		,'ABSTRACT_FROM'       => 'TransactionInput.pm'
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

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile { '' }
