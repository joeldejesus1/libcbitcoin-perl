use 5.014002;
use strict;
use warnings;


use Test::More tests => 1;

require CBitcoin::CBHD;


my $x = CBitcoin::CBHD->new();
$x->generate();
my $address = $x->address();
warn "\nAddress:".$address."\n";
ok ($address, 'get address');


