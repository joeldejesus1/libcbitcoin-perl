#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'CBitcoin::Transaction' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::CBHD' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::TransactionInput' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::TransactionOutput' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::Script' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin::Transaction $CBitcoin::Transaction::VERSION, Perl $], $^X" );
