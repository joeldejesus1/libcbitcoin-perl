#use 5.014002;
use strict;
use warnings;

use CBitcoin ':network_bytes';
use Test::More tests => 7;


require CBitcoin::CBHD;
require Digest::SHA;
require Data::Dumper;


# .........................................................

my $priv = 'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';
my $hash = CBitcoin::CBHD::picocoin_newhdkey($priv);
#CBitcoin::CBHD::print_to_stderr($hash);
ok($hash->{'success'},'priv key from base58');

#warn "Length=".length($hash->{'serialized private'})."\n";
my $base58_priv = CBitcoin::picocoin_base58_encode(
	$hash->{'serialized private'}.
	substr(Digest::SHA::sha256(Digest::SHA::sha256($hash->{'serialized private'})),0,4)
);

ok($priv eq $base58_priv,'base58 encode xpriv');

# .........................................................

my $pub = 'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8';
my $hashxpub = CBitcoin::CBHD::picocoin_newhdkey($pub);
# CBitcoin::CBHD::print_to_stderr($hashxpub);
my $base58_pub = CBitcoin::picocoin_base58_encode(
	$hashxpub->{'serialized public'}.
	substr(Digest::SHA::sha256(Digest::SHA::sha256($hashxpub->{'serialized public'})),0,4)
);

ok($pub eq $base58_pub,'base58 encode xpub');


# .........................................................
$base58_pub = CBitcoin::picocoin_base58_encode(
	$hash->{'serialized public'}.
	substr(Digest::SHA::sha256(Digest::SHA::sha256($hash->{'serialized public'})),0,4)
);

ok($pub eq $base58_pub,'base58 encode xpub from xpriv');

# .........................................................

my $parenthash = CBitcoin::CBHD::picocoin_generatehdkeymaster("my super secret seed/password");

my $privchildhash = CBitcoin::CBHD::picocoin_generatehdkeychild($parenthash->{'serialized private'},12);
#warn "child with index=12:\n".CBitcoin::CBHD::print_to_stderr($hash);

ok(
	$privchildhash->{'success'} && $privchildhash->{'depth'} == 1 && $privchildhash->{'index'} == 12,
	'get child with index=12'
);

$base58_priv = CBitcoin::picocoin_base58_encode(
	$privchildhash->{'serialized public'}.
	substr(Digest::SHA::sha256(Digest::SHA::sha256($privchildhash->{'serialized public'})),0,4)
);

# .........................................................


my $fail_hash = CBitcoin::CBHD::picocoin_generatehdkeychild(
	$parenthash->{'serialized private'}.'fjfjf',12
);


ok(!$fail_hash->{'success'},'Generate child with bad xpriv');


# .........................................................

my $pubchildhash = CBitcoin::CBHD::picocoin_generatehdkeychild($parenthash->{'serialized public'},12);

$base58_pub = CBitcoin::picocoin_base58_encode(
	$pubchildhash->{'serialized public'}.
	substr(Digest::SHA::sha256(Digest::SHA::sha256($pubchildhash->{'serialized public'})),0,4)
);

ok(
	$pubchildhash->{'success'} && $base58_priv eq $base58_pub,
	'Generate xpub child from xpub'
);


#################### test CBHD object ###########################






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