use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CBitcoin::Transaction',
    AUTHOR              => q{Joel De Jesus <dejesus.joel@e-flamingo.jp>},
    VERSION_FROM        => 'lib/CBitcoin/Transaction.pm',
    ABSTRACT_FROM       => 'lib/CBitcoin/Transaction.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'libperl-cbitcoin-*' },
);
