#use 5.014002;
use strict;
use warnings;


use Test::More tests => 1;

require CBitcoin::CBHD;

my $priv = 'xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9';

my $hash = CBitcoin::CBHD::picocoin_newhdkey($priv);

require Data::Dumper;
my $xo = Data::Dumper::Dumper($hash);
warn "Got XO=$xo\n";

$hash = CBitcoin::CBHD::picocoin_generatehdkeymaster("my super secret seed/password");

require Data::Dumper;
$xo = Data::Dumper::Dumper($hash);
warn "Got XO2=$xo\n";

$hash = CBitcoin::CBHD::picocoin_generatehdkeychild($hash->{'data'},1);

require Data::Dumper;
$xo = Data::Dumper::Dumper($hash);
warn "Got XO3=$xo\n";


ok($hash->{'success'}, 'get success');


__END__

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
$s1 = $root->deriveChild(1,1);
#warn "Root->(soft,1):".$s1->address()."\n... and public key=".$s1->publickey()."\n";
#warn "...serialized data=".$s1->serialized_data()."\n";
$s1s2 = $s1->deriveChild(0,323);
warn "network=".$s1s2->network_bytes()." and type=".$s1s2->cbhd_type()."\n";
warn "Root->(hard,1)->(soft,323):".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
warn "...serialized data=".$s1s2->serialized_data()."\n";

$s1s2 = $s1->deriveChild(1,323);
warn "network=".$s1s2->network_bytes()." and type=".$s1s2->cbhd_type()."\n";
warn "Root->(hard,1)->(hard,323):".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
warn "...serialized data=".$s1s2->serialized_data()."\n";



#$s1s2 = $s1s2->exportPublicExtendedCBHD($s1s2->serialized_data());
warn "Root->(soft,1)->(soft,323):".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
warn "...serialized data=".$s1s2->serialized_data()."\n";


# strip private parts from soft child

# root->(soft,1)
$s1 = $root->deriveChildPubExt(1);
#warn "Root->(soft,1) with no private parts:".$s1->address()."\n... and public key=".$s1->publickey()."\n";
#warn "...serialized data=".$s1->serialized_data()."\n";

$s1s2 = $s1->deriveChildPubExt(323);
warn "Root->(soft,1)->(soft,323) with no private parts:".$s1s2->address()."\n... and public key=".$s1s2->publickey()."\n";
warn "...serialized data=".$s1s2->serialized_data()."\n";
warn "network=".$s1s2->network_bytes()." and type=".$s1s2->cbhd_type()."\n";

ok ($address, 'get address');