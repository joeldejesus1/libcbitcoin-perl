#!perl -T
use 5.006;
use Test::More tests => 1;

BEGIN {
    use_ok( 'CBitcoin' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::CBHD' ) || print "Bail out!\n";
    use_ok( 'CBitcoin::Script' ) || print "Bail out!\n";
}

diag( "Testing CBitcoin $CBitcoin::VERSION, Perl $], $^X" );

