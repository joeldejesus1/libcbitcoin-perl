use 5.014002;
use strict;
use warnings;


use Test::More tests => 1;

require CBitcoin::CBHD;

warn "Starting\n";

my ($address,$h1,$s1,$s1s2);

my $root = CBitcoin::CBHD->new();
$root->generate();
$address = $root->address();
warn "Address:".$address."\n";

# root->(hard,1)
$h1 = $root->deriveChild(1,1);
#warn "Root->(hard,1):".$h1->address()."\n... and public key=".$h1->publickey()."\n";

# root->(soft,1)
$s1 = $root->deriveChild(0,1);
#warn "Root->(soft,1):".$s1->address()."\n... and public key=".$s1->publickey()."\n";
#warn "...serialized data=".$s1->serialized_data()."\n";
$s1s2 = $s1->deriveChild(0,323);
#warn "Root->(soft,1)->(soft,323):".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
#warn "...serialized data=".$s1s2->serialized_data()."\n";

# strip private parts from soft child

# root->(soft,1)
$s1 = $root->deriveChildPubExt(1);
#warn "Root->(soft,1) with no private parts:".$s1->address()."\n... and public key=".$s1->publickey()."\n";
#warn "...serialized data=".$s1->serialized_data()."\n";

$s1s2 = $s1->deriveChildPubExt(323);
#warn "Root->(soft,1)->(soft,323) with no private parts:".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
#warn "...serialized data=".$s1s2->serialized_data()."\n";


ok ($address, 'get address');