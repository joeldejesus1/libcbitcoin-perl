package CBitcoin::Script;

use strict;
use warnings;

use CBitcoin;

=head1 NAME

CBitcoin::Script - A wrapper for handling Bitcoin Transaction Scripts

=cut

use Digest::SHA qw(sha256);

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Script::VERSION = $CBitcoin::VERSION;

DynaLoader::bootstrap CBitcoin::Script $CBitcoin::VERSION;

@CBitcoin::Script::EXPORT = ();
@CBitcoin::Script::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=pod

---++ convert_OP_to_CCOIN($string,$push_bytes_bool)

OP_HASH160 -> ccoin_OP_HASH160;

=cut

sub convert_OP_to_CCOIN {
	my ($string,$push_bytes_bool) = @_;
	die "no script" unless defined $string;
	my @newarray;
	foreach my $element (split(' ',$string)){
		if($element =~ m/^OP_/){
			push(@newarray,'ccoin_'.$element);
		}
		elsif($element =~ m/^0x([0-9a-fA-F]+)$/ && $push_bytes_bool){
			my $x = $1;
			my $y = pack('C',length($x)/2);
			push(@newarray,'0x'.unpack('H*',$y),'0x'.$x);
		}
		else{
			push(@newarray,$element);
		}
	}
	return join(' ',@newarray);
}

=pod

---++ convert_CCOIN_to_OP(@x)

ccoin_OP_HASH160 -> OP_HASH160;

=cut

sub convert_CCOIN_to_OP {
	my @newarray;
	foreach my $element (@_){
		chomp($element);
		if($element =~ m/^ccoin_(OP_.*)/){
			push(@newarray,$1);
		}
		elsif($element =~ m/^0x(\d{2})$/){
			# skip, because it is a length
		}
		else{
			push(@newarray,$element);
		}
	}
	return join(' ',@newarray);
}

=pod

---++ prefix('p2sh')

Map prefixes to integer.

See https://en.bitcoin.it/wiki/List_of_address_prefixes.

=cut
our $mapper_mainnet = {
	'p2pkh' => 0x00, 'p2sh' => 0x05,
	0x00 => 'p2pkh', 0x05 => 'p2sh'
};

our $mapper_testnet = {
	'p2pkh' => 0x6F, 'p2sh' => 0xC4,
	0x6F => 'p2pkh', 0xC4 => 'p2sh'
};


sub prefix {
	my $type = shift;
	
	my $mapper;

	my $x = {
		CBitcoin::MAINNET => $mapper_mainnet
		,CBitcoin::TESTNET => $mapper_testnet
		,CBitcoin::TESTNET3 => $mapper_testnet
		,CBitcoin::REGNET => $mapper_testnet
	};

	if(defined $x->{$CBitcoin::network_bytes}){
		$mapper = $x->{$CBitcoin::network_bytes};
	}
	else{
		die "bad network bytes";
	}


	if(defined $type && defined $mapper->{$type}){
		return $mapper->{$type};
	}
	else{
		die "invalid prefix of $type";
	}
	
}

=pod

---++ what_network_is_address()

Are we on MAINNET ('production') or TESTNET ('test')?

=cut

sub what_network_is_address {
	my $x = shift;
	die "bad address" unless defined $x && 0 < length($x);
	$x = CBitcoin::picocoin_base58_decode($x);
	die "bad address" unless defined $x && 0 < length($x);
	my $prefix = unpack('C',substr($x,0,1) );
	
	
	if(defined $mapper_mainnet->{$prefix}){
		return 'production';
	}
	elsif(defined $mapper_testnet->{$prefix}){
		return 'test';
	}
	else{
		return 'unknown';
	}
}

=pod

---++ address_to_script

=cut


sub address_to_script {
	#use bigint;
	my $x = shift;
	
	die "bad address" unless defined $x && 0 < length($x);
	$x = CBitcoin::picocoin_base58_decode($x);
	die "bad address" unless defined $x && 0 < length($x);

	
	my $prefix = prefix(unpack('C',substr($x,0,1)));
	my $hash = substr($x,1,20);
	unless(
		substr($x,21,4) eq
			substr(Digest::SHA::sha256(Digest::SHA::sha256(substr($x,0,21))),0,4) 
	){
		return undef;
	}
	
	# change to hex	
	if($prefix eq 'p2pkh'){
		return 'OP_DUP OP_HASH160 0x'.unpack('H*',$hash).' OP_EQUALVERIFY OP_CHECKSIG';
	}
	elsif($prefix eq 'p2sh'){
		return 'OP_HASH160 0x'.unpack('H*',$hash).' OP_EQUAL';
	}
	else{
		die "should not be here.";
	}
}



=pod

---++ script_to_address

=cut

sub script_to_address {
	#use bigint;
	my $x = shift;
	die "no script given" unless defined $x && 0 < length($x);
	
	my $type = whatTypeOfScript($x);
	my $serialized_script = serialize_script($x);
	my ($hash,$prefix);
	
	# this part only works for OP_HASH160
	if($type eq 'multisig'){
		# need to get p2sh 
		$prefix = pack('C',prefix('p2sh'));
		$hash = CBitcoin::picocoin_ripemd_hash160($serialized_script);
	}
	elsif($type eq 'p2sh'){
		# we have: OP_HASH160 0x14 0x3dbcec384e5b32bb426cc011382c4985990a1895 OP_EQUAL
		die "bad script length" unless length($serialized_script) == 23;
		$prefix = pack('C',prefix('p2sh'));
		$hash = substr($serialized_script,2,20);
	}
	elsif($type eq 'pubkey'){
		die "cannot handle pubkey";
	}
	elsif($type eq 'p2pkh'){
		# we have: OP_DUP OP_HASH160 0x14 0x3dbcec384e5b32bb426cc011382c4985990a1895 OP_EQUALVERIFY OP_CHECKSIG
		$prefix = pack('C',prefix('p2pkh'));
		die "bad script length" unless length($serialized_script) == 25;
		$hash = substr($serialized_script,3,20);
	}
	else{
		die "bad type";
	}

	my $address = $prefix.$hash.substr(
		Digest::SHA::sha256(Digest::SHA::sha256($prefix.$hash)),
		0,4
	);
	return CBitcoin::picocoin_base58_encode($address);
	
}

sub whatTypeOfScript {
	my $x = shift;
	die "undefined type" unless defined $x && 0 < length($x);
	my @s = split(' ',$x);
	
	if(scalar(@s) == 3 && $s[0] eq 'OP_HASH160' && $s[2] eq 'OP_EQUAL'){
		return 'p2sh';
	}
	elsif(
		scalar(@s) == 5 && $s[0] eq 'OP_DUP' && $s[1] eq 'OP_HASH160'
		&& $s[3] eq 'OP_EQUALVERIFY' && $s[4] eq 'OP_CHECKSIG'
	){
		return 'p2pkh';	
	}
	elsif($s[-1] eq 'OP_CHECKMULTISIG'){
		return 'multisig';
	}
	elsif($s[0] eq 'OP_RETURN'){
		return 'return';
	}
	elsif(scalar(@s) == 2 && $s[-1] eq 'OP_CHECKSIG'){
		return 'p2p';
	}
	else{
		return 'unknown';
	}
	
	
}

=pod

---++ serialize_script

=cut

sub serialize_script {
	my $x = shift;
	return undef unless defined $x;
	return picocoin_script_decode(convert_OP_to_CCOIN($x,1));
}


=pod

---++ deserialize_script

=cut

sub deserialize_script {
	my $x = shift;
	return undef unless defined $x && 0 < length($x);
	$x = picocoin_parse_script($x);
	# ? do we have to pop the last item?
	pop(@{$x}) if $x->[-1] eq '1';
	return convert_CCOIN_to_OP(@{$x});
}

=pod

---++ deserialize_scriptSig

=cut

sub deserialize_scriptSig {
	my $x = shift;
	return undef unless defined $x && 0 < length($x);
	
	picocoin_parse_scriptsig($x);
	
	#$x = picocoin_parse_script($x);
	#return convert_CCOIN_to_OP(@{$x});
}



=pod

---++ multisig_p2sh_script($m,$n,@pubksy)

Public keys must be in binary form (between 32 and 34 bytes long).

=cut

sub multisig_p2sh_script {
	my ($m,$n)= (shift,shift);
	
	die "bad n size" unless defined $n && $n =~ m/^\d+$/ && 1 < $n && $n <= 15;
	die "bad m size" unless defined $m && $m =~ m/^\d+$/ && 0 < $m && $m <= $n;
	my @ins = sort @_;
	
	die "bad number of pubkeys" unless scalar(@ins) == $n;
	
	my @pubs;
	foreach my $pubkey (@ins){
		die "bad public key" unless defined $pubkey && 32 <= length($pubkey) && length($pubkey) < 34;
		push(@pubs,'0x'.unpack('H*',$pubkey));
	}
	
	return "OP_$m ".join(' ',@pubs)." OP_$n OP_CHECKMULTISIG";
}


=pod

---+ extraction

=cut

=pod

---++ p2p_publickey

Get public key from script.

=cut

sub p2p_publickey($){
	my $x = shift;
	return undef unless whatTypeOfScript($x) eq 'p2p';
	my $y = chunks($x);
	die "no chunks" unless defined $y;
	if($y->[0] =~ m/^0[x]([0-9a-fA-F]+)/){
		return pack('H*',$1);
	}
	else{
		return undef;
	}
}

=pod

---++ p2pkh_ripemd

Get ripemd hash from script.

=cut

sub p2pkh_ripemd($){
	my $x = shift;
	return undef unless whatTypeOfScript($x) eq 'p2pkh';
	my $y = chunks($x);
	die "no chunks" unless defined $y;
	#  OP_DUP OP_HASH160 0x14 0x3dbcec384e5b32bb426cc011382c4985990a1895 OP_EQUALVERIFY OP_CHECKSIG
	# 0x14 may or may not be there, so start index fromo the end, not beginning.
	if($y->[-3] =~ m/^0[x]([0-9a-fA-F]+)/){
		return pack('H*',$1);
	}
	else{
		return undef;
	}
}

=pod

---++ chunks($script)->[]

Return an array with 0x21438 hex values in binary form.

=cut

sub chunks($){
	my $x = shift;
	die "no script" unless defined $x;
	my @y = split(/\s+/,$x);
	return \@y;
}

=head1 SYNOPSIS

  use CBitcoin;
  use CBitcoin::Script;

  
=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/favioflamingo/libcbitcoin-perl>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::Script


You can also look for information at: L<https://github.com/favioflamingo/libcbitcoin-perl>

=over 4

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::Script
__END__