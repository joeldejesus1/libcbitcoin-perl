#use 5.014002;
use strict;
use warnings;

use CBitcoin;
use Crypt::CBC;
use Digest::SHA;
use Test::More tests => 15;


require CBitcoin::CBHD;
require Digest::SHA;
require Data::Dumper;


my $vers = 0;
if($CBitcoin::network_bytes eq CBitcoin::MAINNET){
	$vers = CBitcoin::BIP32_MAINNET_PRIVATE;
}
elsif($CBitcoin::network_bytes eq CBitcoin::TESTNET){
	$vers = CBitcoin::BIP32_TESTNET_PRIVATE;
}
else{
	die "bad network bytes";
}


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
my $parenthash = CBitcoin::CBHD::picocoin_generatehdkeymaster("my super secret seed/password",$vers);
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

=pod

{
	my $root = CBitcoin::CBHD->generate("my magic seed! 123456789012345678901234567890");
	
	
#	my ($private_key,$public_key) = (
#		CBitcoin::CBHD::picocoin_offset_private_key($root->privatekey,"hello mother.")	
#		,CBitcoin::CBHD::picocoin_offset_public_key($root->publickey,"hello mother.")
#	);
	
	my ($private_key,$public_key) = (
		$root->privatekey
		,$root->publickey
	);
	
	
	my $plaintext1 = 'Please encrypt me!';
	open(my $fh1,'<',\$plaintext1);
	my $readsub1 = sub{
		my ($xref,$n) = @_;
		return read($fh1,$$xref,$n);
	};
	my $ciphertext1 = ''; 
	my $writesub1 = sub{
		my ($xref) = @_;
		$ciphertext1 .= $$xref;
		return length($$xref);
	};	
	my $header = CBitcoin::CBHD::encrypt($public_key,$readsub1,$writesub1);
	
	########### decrypt##############
	
	my $ciphertext2 = $ciphertext1;
	open(my $fh2,'<',\$ciphertext2);
	my $readsub2 = sub{
		my ($xref,$n) = @_;
		return read($fh2,$$xref,$n);
	};
	my $plaintext2 = '';
	my $writesub2 = sub{
		my ($xref) = @_;
		$plaintext2 .= $$xref;
		return length($$xref);
	};
	
	my $success = CBitcoin::CBHD::decrypt($private_key,$header,$readsub2,$writesub2);
	
	ok($success,'did decryption work?');
	
	
	ok($plaintext1 eq $plaintext2, 'did we get back the plain text?');

	my $newstuff = CBitcoin::CBHD::picocoin_offset_private_key($root->privatekey,"hello mother.");
	my ($priv,$pub) = (substr($newstuff,0,32),substr($newstuff,32));
	my $pub2 = CBitcoin::CBHD::picocoin_offset_public_key($root->publickey,"hello mother.");
	
	
	ok($pub eq $pub2, 'Is it possible to make a new private/public EC_Key using an arbitrary string as an offset?');
}
=cut



__END__

