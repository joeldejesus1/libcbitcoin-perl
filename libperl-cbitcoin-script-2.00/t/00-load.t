#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'CBitcoin::Script' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::Script $CBitcoin::Script::VERSION, Perl $], $^X" );
