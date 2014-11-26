#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'CBitcoin::CBHD' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::CBHD $CBitcoin::CBHD::VERSION, Perl $], $^X" );
