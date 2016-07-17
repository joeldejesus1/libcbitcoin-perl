package CBitcoin::Transaction;

use 5.014002;
use strict;
use warnings;

use constant {
	SIGHASH_ALL => 0x00000001, # <--- this is the default
	SIGHASH_NONE => 0x00000002,
	SIGHASH_SINGLE => 0x00000003,
	SIGHASH_ANYONECANPAY => 0x00000080,
	
	OP_PUSHDATA1 => 0x4c,
	OP_PUSHDATA2 => 0x4d,
	OP_PUSHDATA4 => 0x4e
};

=head1 NAME

CBitcoin::Transaction - The great new CBitcoin::Transaction!

=head1 VERSION

Version 0.01

=cut

use bigint;
use CBitcoin;
use CBitcoin::Script;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Utilities;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Transaction::VERSION = '0.1';

DynaLoader::bootstrap CBitcoin::Transaction $CBitcoin::VERSION;

@CBitcoin::Transaction::EXPORT = ();
@CBitcoin::Transaction::EXPORT_OK = ();

=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

our $default_version = 1;
our $default_locktime = 0;

=item new

---++ new($options)

<verbatim>$options = {
	'inputs' => \@txinputs, 'outputs' => \@txoutputs
};</verbatim>


=cut

sub new {
	my $package = shift;

	my $this = bless({
		'version' => $default_version
	}, $package);
	my $options = shift;


	if(
		defined $options && ref($options) eq 'HASH'
		&& defined $options->{'inputs'} && ref($options->{'inputs'}) eq 'ARRAY'
		&& defined $options->{'outputs'} && ref($options->{'outputs'}) eq 'ARRAY'
	){
		my ($n,$m,$i,$j);
		
		$j = 'inputs';
		$n = scalar(@{$options->{$j}});
		for($i=0;$i<$n;$i++){
			die "bad type in $j with ref=".ref($options->{$j}->[$i]) 
				unless ref($options->{$j}->[$i]) eq 'CBitcoin::TransactionInput';
			$this->{$j}->[$i] = $options->{$j}->[$i];
		}

		$j = 'outputs';
		$n = scalar(@{$options->{$j}});
		for($i=0;$i<$n;$i++){
			die "bad type in $j with ref=".ref($options->{$j}->[$i]) 
				unless ref($options->{$j}->[$i]) eq 'CBitcoin::TransactionOutput';
			$this->{$j}->[$i] = $options->{$j}->[$i];
		}
			
	}
	else{
		die "bad inputs";
	}
	
	
	$this->{'lockTime'} = $default_locktime unless defined $this->{'lockTime'};
	$this->{'version'} = $default_version unless defined $this->{'version'};
	
	
	return $this;
}

=pod

---++ deserialize($serialized_tx)


Get a hash back, not a blessed object.

version
inputs => [..]
outputs => [..]
locktime

input = {prevHash, prevIndex, script, sequence}
output = {value, script}

=cut

sub deserialize{
	my ($package,$data) = @_;
	
	

#	return $tx;
}




=item lockTime

---++ lockTime

=cut

sub lockTime {
	return shift->{'lockTime'};
}

=item version

---++ version

=cut

sub version {
	return shift->{'version'};
}

=item hash

---++ hash

=cut

sub hash {
	return shift->{'hash'};
}

=pod

---++ addRedeemScript($input_index,$script)

This adds the redeem script to the end of the stack. (scriptSig in picocoin parlance)

=cut

sub add_redeem_script {
	my $this = shift;
	
}


=item numOfInputs

---++ numOfInputs

=cut

sub numOfInputs {
	return scalar(@{shift->{'inputs'}});
}

=item input

---++ input($index)

=cut

sub input {
	return shift->{'inputs'}->[shift];
}

=item numOfOutputs

---++ numOfOutputs()

=cut

sub numOfOutputs {
	return scalar(@{shift->{'outputs'}});
}

=pod

---++ output($index)

=cut

sub output {
	return shift->{'outputs'}->[shift];
}

=pod

---+ i/o

=cut

=pod

---++ serialize($raw_bool)

=cut

sub serialize {
	my ($this,$raw_bool) = @_;
	
	if($raw_bool && defined $this->{'serialized raw'}){
		return $this->{'serialized raw'};
	}
	
	my $data = pack('l',$this->version);
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfInputs);
	for(my $i=0;$i<$this->numOfInputs;$i++){
		$data .= $this->input($i)->serialize($raw_bool);
	}
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfOutputs);
	for(my $i=0;$i<$this->numOfOutputs;$i++){
		$data .= $this->output($i)->serialize();
	}
	
	$data .= pack('L',$this->lockTime);
	
	if($raw_bool && !(defined $this->{'serialized raw'})){
		$this->{'serialized raw'} = $data;
	}
	
	return $data;
}


=pod

---++ validate($data)

https://en.bitcoin.it/w/images/en/7/70/Bitcoin_OpCheckSig_InDetail.png

=cut

sub validate_syntax{
	my ($this,$data,$full) = @_;
	die "no data provided" unless defined $data && 0 < length($data);

	if($full){
		
		return $this->validate_full($data,@_);
	}
	else{
		return picocoin_tx_validate($data);
	}
	
}

=pod

---++ validate_sigs($data)

https://en.bitcoin.it/w/images/en/7/70/Bitcoin_OpCheckSig_InDetail.png

SCRIPT_VERIFY_NONE -> 1
SCRIPT_VERIFY_STRICTENC -> 2
SCRIPT_VERIFY_P2SH -> 3
SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_STRICTENC -> 4
=cut

sub validate_sigs {
	my ($this,$data) = @_;
	
	# picocoin_tx_validate_input int index, SV* scriptPubKey_data,
	#    SV* txdata,int sigvalidate, int nHashType
	my $txdata;
	if(defined $data){
		$txdata = $data;
	}
	else{
		$txdata = $this->serialize();
	}
	
	my $bool = 1;
	for(my $i=0;$i<$this->numOfInputs;$i++){
		$bool = picocoin_tx_validate_input(
			$i
			, $this->input($i)->script() # scriptPubKey
			, $txdata  # includes scriptSig
			, 0 # sigvalidate
			, SIGHASH_ALL # default;
		);
		return 0 unless $bool;
	}
	return 1;
}

=pod

---++ calculate_signature($key,$index)

https://en.bitcoin.it/wiki/OP_CHECKSIG - has the hash type explanantion
| SIGHASH_ALL | 0x00000001 |
| SIGHASH_NONE | 0x00000002 |
| SIGHASH_SINGLE | 0x00000003 |
| SIGHASH_ANYONECANPAY | 0x00000080 | 

=cut



sub calculate_signature {
	my ($this,$i,$cbhdkey) = @_;
	
	die "bad key" unless defined $cbhdkey && ref($cbhdkey) =~ m/CBHD/;
	
	my $xpriv = $cbhdkey->serialized_private();
	die "bad key" unless defined $xpriv && length($xpriv) == 78;
	
	die "bad index" unless defined $i && 0 <= $i && $i < $this->numOfInputs();
	
	# SV* fromPubKey_data, SV* txdata,int nIndex, int HashType
	my $script = CBitcoin::Script::serialize_script($this->input($i)->script());
	my $data = $this->serialize(1); # 1 for raw_bool=TRUE
	
	return picocoin_tx_sign(
		$xpriv,
		$script,
		$data,
		$i,
		SIGHASH_ALL
	);
}


=pod

---++ assemble_multisig_p2sh($i,$n,@keys,$txraw)

=cut

sub assemble_multisig_p2sh {
	my ($this,$i,$n,@keys,$txraw) = @_;
	# do some testing
	die "bad index" unless defined $i && 0 <= $i && $i < $this->numOfInputs();
	
	die "bad multisig params" unless
		defined $n && 0 < $n && $n < 15
		&& 0 < scalar(@keys) && scalar(@keys) <= $n;
	my $m = scalar(@keys);


	my $txdata;
	if(defined $txraw){
		$txdata = $txraw;
	}
	else{
		$txdata = $this->serialize();
	}
	
	

	
	
	# grab all the sigs
	#my @sigs;
	foreach my $key (@keys){
		#push(@sigs,$this->calculate_signature($i,$key));
		#die "bad signature" unless defined $sigs[-1] && 0 < length($sigs[-1]);
		$txraw = picocoin_tx_sign_p2pkh(
			$key->serialized_private(),
			CBitcoin::Script::serialize_script($this->input($i)->script()),
			$txdata,
			$i,
			SIGHASH_ALL
		);
		die "bad signature" unless defined $txraw && 0 < length($txraw);
		
	}
	return $txraw;
	# OP_PUSHDATA1
}


=pod

---++ assemble_p2pkh($i,$key)

=cut

sub assemble_p2pkh {
	my ($this,$i,$key,$txraw) = @_;
	# do some testing
	die "bad index" unless defined $i && 0 <= $i && $i < $this->numOfInputs();
	
	die "no key" unless defined $key;
	my $txdata;
	if(defined $txraw){
		$txdata = $txraw;
	}
	else{
		$txdata = $this->serialize();
	}

	$txraw = picocoin_tx_sign_p2pkh(
		$key->serialized_private(),
		CBitcoin::Script::serialize_script($this->input($i)->script()),
		$txdata,
		$i,
		SIGHASH_ALL
	);
	die "bad signature" unless defined $txraw && 0 < length($txraw);
	return $txraw;
	
}


=pod

---+ utilities

=cut

=pod

---++ push_data($data)->$adddata


=cut

sub push_data{
	my ($data) = @_;
	return undef unless defined $data && 0 < length($data);
	my $n = length($data);
	
	
	if($n < OP_PUSHDATA1){
		return pack('C',$n).$data;
	}
	elsif($n <= 0xff){
		return pack('C',OP_PUSHDATA1).pack('C',$n).$data;
	}
	elsif($n <= 0xffff){
		return pack('C',OP_PUSHDATA2).pack('S',$n).$data;
	}
	else{
		return pack('C',OP_PUSHDATA4).pack('L',$n).$data;
	}
}


=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-transaction at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::Transaction


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

1; # End of CBitcoin::Transaction
