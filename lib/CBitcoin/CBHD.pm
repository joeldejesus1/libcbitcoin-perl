package CBitcoin::CBHD;

#use 5.014002;
# use bigint; # do not use this, delete on next update
use strict;
use warnings;

use CBitcoin;
use CBitcoin::Script;

=head1 NAME

CBitcoin::CBHD - The great new CBitcoin::CBHD!

=head1 VERSION

Version 0.2

=cut

#use XSLoader;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::CBHD::VERSION = '0.1';

#XSLoader::load('CBitcoin::CBHD',$CBitcoin::CBHD::VERSION );
DynaLoader::bootstrap CBitcoin::CBHD $CBitcoin::VERSION;

@CBitcoin::CBHD::EXPORT = ();
@CBitcoin::CBHD::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

our $minimum_seed_length = 30;

our $default_kdf_sub = sub{			return Digest::SHA::sha256(shift); 	};

# Preloaded methods go here.


# dispatch table, use it in Kgc::Safe

our $dispatch;

=pod

---+ constructors

=cut


=pod

---++ new($xprv_txt)

Create a cbhd object from a serialized, base58 encoded scalar.

TODO: check for the appropriate network bytes.

=cut

BEGIN{
	$dispatch->{'new'} = \&new;
}


sub new {
	my $package = shift;
	my $txt = shift;
	die "no serialized, base58 encoded provided" 
		unless defined $txt && 4 < length($txt);
	
	# Check the network bytes
	my $prefix = substr($txt,0,4);
	if(
		( $prefix eq 'xprv' || $prefix eq 'xpub' )
		&& $CBitcoin::network_bytes eq CBitcoin::MAINNET
	){
		
	}
	elsif(
		( $prefix eq 'tprv' || $prefix eq 'tpub' )
		&& $CBitcoin::network_bytes eq CBitcoin::TESTNET
	){
		
	}
	else{
		die "bad network bytes";
	}
	
	my $this = picocoin_newhdkey($txt);
	
	die "bad xprv/xpub" unless defined $this && $this->{'success'};
	
	bless($this, $package);
	
	return $this;
}

=pod

---++ generate($seed)

generate a key (parent)

=cut

BEGIN{
	$dispatch->{'generate'} = \&generate;
}

sub generate {
	my ($package,$seed) = @_;
	my $this = {};
	if(defined $seed && $minimum_seed_length < length($seed) ){
		$this = picocoin_generatehdkeymaster($seed);
	}
	elsif(!defined $seed){
		# get 32 bytes from /dev/random (we might block here)
		open(my $fh,'<','/dev/random') || die "cannot read any safe random bytes";
		binmode($fh);
		my ($n,$m) = (32,0);
		while(0 < $n - $m){
			$m += sysread($fh,$seed,32,$m);
		}
		close($fh);
		$this = picocoin_generatehdkeymaster($seed);
		if($CBitcoin::network_bytes eq CBitcoin::TESTNET){
			# need to go the long-about route to redo the key with the correct network bytes
			# since this is perl, do it the old fashion way, regex
			bless($this,$package);

			if(defined $this->{'serialized private'}){
				my $x = $this->export_xprv();
				if($x =~ m/^xprv(.*)$/){
					$this = picocoin_newhdkey('tprv'.$1);
				}
				else{
					die "bad format for xprv";
				}
			}
			else{
				my $x = $this->export_xpub();
				if($x =~ m/^xpub(.*)$/){
					$this = picocoin_newhdkey('tpub'.$1);
				}
				else{
					die "bad format for xprv";
				}				
			}
		}
	}
	else{
		die "seed is too short";
	}
	bless($this,$package);
	
	$this->{'is soft child'} = 0;
	
	return $this;
}

=pod

---++ deriveChild($hardbool,$childid)

If you want to go from private parent keypair to public child keypair, then set $hardbool to false.  If you want to 
go from private parent keypair to private child keypair, then set $hardbool to true.

=cut

BEGIN{
	$dispatch->{'deriveChild'} = \&deriveChild;
}

sub deriveChild {
	my ($this,$hardbool,$childid) = @_;
	
	my $childkey;
	if($hardbool && defined $this->{'serialized private'}){
		$childkey = picocoin_generatehdkeychild(
			$this->{'serialized private'},
			(2 << 30) + $childid
		);
	}
	elsif(defined $this->{'serialized private'}){
		$childkey = picocoin_generatehdkeychild($this->{'serialized private'},$childid);
	}
	else{
		die "no private data";
	}

	if(!defined $childkey || !($childkey->{'success'})){
		return undef;
	}
	bless($childkey,ref($this));
	return $childkey;
}

=pod

---++ deriveChildPubExt($childid)

If you want to take an CBHD key with private key and create a soft child that does not have the private bits, then use this function.

From Hard to Soft.

=cut

BEGIN{
	$dispatch->{'deriveChildPubExt'} = \&deriveChildPubExt;
}

sub deriveChildPubExt {
	my ($this,$childid) = @_;
	
	# soft key so $childid < 2^31
	my $childkey = picocoin_generatehdkeychild($this->{'serialized public'},$childid);

	if(!defined $childkey || !($childkey->{'success'})){
		return undef;
	}
	
	bless($childkey,ref($this));
	
	return $childkey;
}


=pod

---+ utilities

=cut

=pod

---++ is_soft_child

Returns true if yes, false if soft.

=cut

BEGIN{
	$dispatch->{'is_soft_child'} = \&is_soft_child;
}

sub is_soft_child {
	my $this = shift;
	
	return $this->{'is soft child'} if defined $this->{'is soft child'};
	
	if( $this->{'index'} < ( 2 << 30) && $this->{'index'} != 0){
		$this->{'is soft child'} = 1;
	}
	else{
		$this->{'is soft child'} = 0;
	}
	
	return $this->{'is soft child'};
}



=pod

---++ export_xpub

=cut

BEGIN{
	$dispatch->{'export_xpub'} = \&export_xpub;
}

sub export_xpub {
	my $this = shift;
	
	return $this->{'xpub'} if defined $this->{'xpub'};
	
	$this->{'xpub'} = CBitcoin::picocoin_base58_encode(
		$this->{'serialized public'}.
		substr(Digest::SHA::sha256(Digest::SHA::sha256(
			$this->{'serialized public'}))
		,0,4)
	);	
	return $this->{'xpub'};
}

=pod

---++ export_xprv

=cut

BEGIN{
	$dispatch->{'export_xprv'} = \&export_xprv;
}

sub export_xprv {
	my $this = shift;
	
	return $this->{'xprv'} if defined $this->{'xprv'};
	
	$this->{'xprv'} = CBitcoin::picocoin_base58_encode(
		$this->{'serialized private'}.
		substr(Digest::SHA::sha256(Digest::SHA::sha256(
			$this->{'serialized private'}))
		,0,4)
	);
	
	return $this->{'xprv'};
}

sub serialized_private {
	return shift->{'serialized private'};
}

sub serialized_public {
	return shift->{'serialized public'};
}

=pod

---++ network_bytes()

Return either 'production' or 'test' depending on whether we are on testnet or mainnet

=cut

BEGIN{
	$dispatch->{'network_bytes'} = \&network_bytes;
}

sub network_bytes {
	my $this = shift;
	my $xpub = $this->export_xpub();
	
	if($xpub =~ m/^xpub/){
		return 'production';
	}
	elsif($xpub =~ m/^tpub/){
		return 'test';
	}
	else{
		return 'unknown';
	}
}


=pod

---++ cbhd_type

Return 'private' if we posses the serialized private key, else return public.

=cut

BEGIN{
	$dispatch->{'cbhd_type'} = \&cbhd_type;
}

sub cbhd_type {
	my $this = shift;

	if(defined $this->{'serialized private'}){
		return 'private';
	}
	else{
		return 'public';
	}
	
}


=pod

---++ address()

The network bytes are determined by the global variable $CBitcoin::network_bytes.

=cut

BEGIN{
	$dispatch->{'address'} = \&address;
}

sub address {
	my $this = shift;
	
	return $this->{'address'} if defined $this->{'address'};
	
	my $script = 'OP_DUP OP_HASH160 0x'.unpack('H*',$this->{'ripemdHASH160'})
		.' OP_EQUALVERIFY OP_CHECKSIG';
	
	$this->{'address'} = CBitcoin::Script::script_to_address($script);
	return $this->{'address'};
}

=pod

---++ publickey()

Provide the public key in raw binary form.

=cut


sub publickey {
	return shift->{'public key'};
}

=pod

---++ privatekey()

Provide the private key in raw binary form.

=cut

sub privatekey {
	return shift->{'private key'};
}

=pod

---++ ripemdHASH160

=cut

sub ripemdHASH160 {
	return shift->{'ripemdHASH160'};
}


=pod

---++ index

=cut

BEGIN{
	$dispatch->{'new'} = \&new;
}

sub index {
	my ($this) = @_;
	
	
	return $this->{'real index'} if defined $this->{'real index'};
	
	if( 0 <= $this->{'index'} && $this->{'index'} < ( 2 << 30)  ){
		$this->{'real index'} = $this->{'index'};
	}
	else{
		$this->{'real index'} = $this->{'index'} - (2 << 30);
	}
	
	return $this->{'real index'};
}

=pod

---++ childid->($hardbool,$index)

=cut

BEGIN{
	$dispatch->{'new'} = \&new;
}

sub childid {
	my ($this) = @_;
	my $hardbool = 1;
	if($this->is_soft_child()){
		$hardbool = 0;
	}
	return ($hardbool,$this->index());
}


=pod

---++ print_to_stderr

=cut

sub print_to_stderr {
	my $this = shift;
	warn "version=".$this->{'version'}."\n";
	warn "Depth=".$this->{'depth'}."\n";
	warn "index=".$this->{'index'}."\n";
	warn "success=".$this->{'success'}."\n";
	warn "serialized private=".unpack('H*',$this->{'serialized private'})."\n";
	warn "serialized public=".unpack('H*',$this->{'serialized public'})."\n";
	warn "Depth=".$this->{'depth'}."\n";

}

=pod

---+ encryption

These are just subroutines, not object methods.

=cut

=pod

---++ encrypt($recepient_pub,$readsub,$writesub)->$cipher_data

$cipher_data = $hmac.$ephemeral_pubkey.$ciphertext

$hmac = hmac_sha256(sha256(data),shared_secret);

=cut

sub encrypt {
	my ($recepient_pub,$readsub,$writesub) = @_;

	my $shared_secret = CBitcoin::CBHD::picocoin_ecdh_encrypt($recepient_pub);
	
	
	die "no shared secret calculated" unless defined $shared_secret && 32 < length($shared_secret);
	
	my $ephemeral_pubkey = substr($shared_secret,32);
	$shared_secret = $default_kdf_sub->(substr($shared_secret,0,32));

	my $cipher = Crypt::CBC->new(-key    => $shared_secret, -cipher => "Crypt::OpenSSL::AES" );
	$cipher->start('encrypting');

	my $sha = Digest::SHA->new(256);

	my $buf = '';
	
	while($readsub->(\$buf,8192)){
		my $cipherbuf = $cipher->crypt($buf);
		$sha->add($cipherbuf);
		
		my ($m,$n) = (0,length($cipherbuf));
		
		while(0 < $n - $m){
			$m += $writesub->(\$cipherbuf,8192);
		}
	}
	{
		# need to do one more loop
		my $cipherbuf = $cipher->finish();
		$sha->add($cipherbuf);
		my ($m,$n) = (0,length($cipherbuf));
		
		while(0 < $n - $m){
			$m += $writesub->(\$cipherbuf,8192);
		}
	}
	
	
	
	my $hmac = Digest::SHA::hmac_sha256($ephemeral_pubkey.$sha->digest,$shared_secret);
	
	return $hmac.$ephemeral_pubkey;
}

=pod

---++ decrypt($recepient_priv,$header,$readsub,$writesub)->0/1

$cipher_data = $hmac.$ephemeral_pubkey.$ciphertext

=cut

sub decrypt {
	my ($recepient_priv,$header,$readsub,$writesub) = @_;
	
	my $hmac2 = substr($header,0,32);
	my $ephemeral_pubkey = substr($header,32);
	
	my $sha = Digest::SHA->new(256);
	
	my $shared_secret = shared_secret($ephemeral_pubkey,$recepient_priv,$default_kdf_sub);
	#my $shared_secret = CBitcoin::CBHD::picocoin_ecdh_decrypt($ephemeral_pubkey,$recepient_priv);
	die "no shared secret calculated" unless defined $shared_secret && length($shared_secret) == 32;
	my $cipher = Crypt::CBC->new(-key    => $shared_secret, -cipher => "Crypt::OpenSSL::AES" );
	$cipher->start('decrypting');
	my $buf = '';
	while($readsub->(\$buf,8192)){
		$sha->add($buf);
		my $plainbuf = $cipher->crypt($buf);
		
		my ($m,$n) = (0,length($plainbuf));
		while(0 < $n - $m){
			$m += $writesub->(\$plainbuf,8192);
		}		
	}
	{
		# need to do one more loop
		my $plainbuf = $cipher->finish();
		#$sha->add($plainbuf);
		my ($m,$n) = (0,length($plainbuf));
		
		while(0 < $n - $m){
			$m += $writesub->(\$plainbuf,8192);
		}
	}
	
	my $hmac = Digest::SHA::hmac_sha256($ephemeral_pubkey.$sha->digest,$shared_secret);
	
	if($hmac eq $hmac2){
		return 1;
	}
	else{
		return 0;
	}
}


=pod

---++ offset_keypair_private

Given a private key and an offset, create a new private/public keypair.

=cut

sub offset_keypair_private {
	my ($private_key,$offset) = @_;
	die "no offset given" unless defined $offset && 0 < length($offset);
	
	# make sure it is 256bits, which is the size of the secp256k1 field.
	$offset = Digest::SHA::sha256($offset);
	
	
}


=pod

---++ shared_secret($pubkey,$privkey,$kdf1_sub)->0/1

=cut

sub shared_secret {
	my ($pubkey,$privkey,$kdfsub) = @_;
	
	die "no pub/priv key[".length($pubkey)."][".length($privkey)."]" unless $pubkey && $privkey;
	
	if(defined $kdfsub && ref($kdfsub) ne 'CODE'){
		die "bad kdf";
	}
	elsif(!defined $kdfsub){
		$kdfsub = $default_kdf_sub;
	}
	
	
	my $ss = CBitcoin::CBHD::picocoin_ecdh_decrypt($pubkey,$privkey);
	return undef unless defined $ss && 0 < length($ss);
	
	return $kdfsub->($ss);	
}


=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-cbhd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::CBHD


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=libperl-cbitcoin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/libperl-cbitcoin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/libperl-cbitcoin>

=item * Search CPAN

L<http://search.cpan.org/dist/libperl-cbitcoin/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::CBHD
