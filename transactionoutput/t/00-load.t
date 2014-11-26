#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'CBitcoin::TransactionOutput' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::TransactionOutput $CBitcoin::TransactionOutput::VERSION, Perl $], $^X" );
