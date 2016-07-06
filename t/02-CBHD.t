#use 5.014002;
use strict;
use warnings;

use CBitcoin;
use Crypt::CBC;
use Digest::SHA;
use Test::More tests => 18;


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
{
	my ($address,$h1,$s1,$s1s2);
	
	my $root1 = CBitcoin::CBHD->generate("my magic seed! 123456789012345678901234567890");
	ok(defined $root1->address(),'can we get an address?');
	
	my $root2 = CBitcoin::CBHD->generate("my magic seed! 123456789012345678901234567890");
	ok($root1->address() eq $root2->address(),'can we get the same address?');
	
	my $child_hard = $root1->deriveChild(1,323);
	ok(!$child_hard->is_soft_child(),'get hard child');
	
	my $c_1_323_0_20_priv = $child_hard->deriveChild(0,20);
	ok($c_1_323_0_20_priv->is_soft_child(),'get soft child');
	
	# 11 tests so far
	my $c_1_323_0_20_0_13_priv = $child_hard->deriveChild(0,20)->deriveChild(0,13);
	
	my $c_1_323_0_20_0_13_pub = $c_1_323_0_20_priv->deriveChildPubExt(13);
	ok(
		$c_1_323_0_20_0_13_pub->address() eq $c_1_323_0_20_0_13_priv->address(),
		'Do addresses match?'
	);
	
	
	ok(
		$root1->deriveChild(0,1)->address() ne $root1->deriveChild(0,2)->address(),
		'should be different addresses (0,1) vs (0,2)'
	);
	
	ok(
		$root1->deriveChild(0,1)->address() ne $root1->deriveChild(1,1)->address(),
		'should be different addresses (0,1) vs (1,1)'
	);
	
	ok(
		$root1->deriveChild(1,1)->address() ne $root1->deriveChild(1,2)->address(),
		'should be different addresses (1,1) vs (1,2)'
	);
}

##################### Test ECDH ##########################
=pod

---+ ECDH

The purpose here is to be able to encrypt/decrypt data using key pairs derived from secp256k1.

=cut

{
	my $root = CBitcoin::CBHD->generate("my magic seed! 123456789012345678901234567890");
	#my @sender_keys = ($root->privatekey,$root->publickey);
	my $root_0_1 = $root->deriveChild(0,1);
	my @recepient_keys = ($root_0_1->privatekey,$root_0_1->publickey);
	
	my $shared_secret = CBitcoin::CBHD::picocoin_ecdh_encrypt($recepient_keys[1]);
	my $eph_pub = substr($shared_secret,32);
	$shared_secret = substr($shared_secret,0,32);
	
	my $ssec2 = CBitcoin::CBHD::picocoin_ecdh_decrypt($eph_pub,$recepient_keys[0]);

	
	ok($shared_secret eq $ssec2,'can we recalculate shared secret?');
	
	my $cipher = Crypt::CBC->new(-key    => $shared_secret, -cipher => "Crypt::OpenSSL::AES" );
	my $plaintext = 'I would like to have an audience with your queen.';
	my $ciphertext = $cipher->encrypt($plaintext);
	my $data = pack('C',length($eph_pub)).$eph_pub.$ciphertext;
	my $hmac = Digest::SHA::hmac_sha256($data,$shared_secret);
	$data = $hmac.$data;

	$cipher = Crypt::CBC->new(-key    => $ssec2, -cipher => "Crypt::OpenSSL::AES" );
	my ($hmac2,$l2,$ephpub2);
	$hmac2 = substr($data,0,32);
	$data = substr($data,32);
	ok($hmac2 eq Digest::SHA::hmac_sha256($data,$ssec2),'matching hmac?');
	
	$l2 = unpack('C',substr($data,0,1));
	$ephpub2 = substr($data,1,$l2);
	$ciphertext = substr($data,1 + $l2);
	my $plaintext2 = $cipher->decrypt($ciphertext);	
	ok($plaintext eq $plaintext2,'Can we encrypt and decrypt data?');
}




__END__

