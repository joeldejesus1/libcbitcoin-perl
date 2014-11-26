#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'CBitcoin::TransactionInput' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::TransactionInput $CBitcoin::TransactionInput::VERSION, Perl $], $^X" );
