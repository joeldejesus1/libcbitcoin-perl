#use 5.014002;
use strict;
use warnings;


use Test::More tests => 4;

require CBitcoin;
require CBitcoin::CBHD;
require Data::Dumper;



my $priv = 'xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U';
my $hash = CBitcoin::CBHD::picocoin_newhdkey($priv);
CBitcoin::CBHD::print_to_stderr($hash);
ok($hash->{'success'},'priv key from base58');

my $base58_priv = CBitcoin::picocoin_base58_encode($hash->{'serialized private'});
warn "Got xpriv=$base58_priv\n";
ok($priv eq $base58_priv,'base58 encode xpriv');


$hash = CBitcoin::CBHD::picocoin_generatehdkeymaster("my super secret seed/password");

$hash = CBitcoin::CBHD::picocoin_generatehdkeychild($hash->{'serialized private'},12);
#warn "child with index=12:\n".CBitcoin::CBHD::print_to_stderr($hash);




ok($hash->{'success'} && $hash->{'depth'} == 1 && $hash->{'index'} == 12, 'get child with index=12');

my $fail_hash = CBitcoin::CBHD::picocoin_generatehdkeychild($hash->{'serialized private'}.'fjfjf',12);

ok(!$fail_hash->{'success'},'should fail');


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