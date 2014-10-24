#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'CBitcoin::Transaction' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::Transaction $CBitcoin::Transaction::VERSION, Perl $], $^X" );
