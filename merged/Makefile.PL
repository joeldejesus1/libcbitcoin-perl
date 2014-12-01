use 5.014002;
use strict;
use warnings;
use ExtUtils::MakeMaker;


WriteMakefile(
	    'TYPEMAPS' => []
	    ,'NAME' => 'CBitcoin'
	     ,'LIBS' => [ ' -lcrypto -lcbitcoin ' ]
		,'VERSION' => '0.01'

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
	#,'LDDLFLAGS' => ' -fstack-protector '
	#,'LDFLAGS' => ' -fstack-protector '
	,'MAKEFILE_OLD' => ''
	,'dist'                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', }
	,'clean'               => { FILES => 'libperl-cbitcoin-*' }
);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile { '' }
