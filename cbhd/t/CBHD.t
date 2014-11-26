use strict;
use warnings;


use Test::More tests => 1;

require CBitcoin::CBHD;


my $x = CBitcoin::CBHD->new();
$x->generate();
warn "Address:".$x->address()."\n";
ok (1, 'get address');


