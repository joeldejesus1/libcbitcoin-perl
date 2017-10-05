package CBitcoin::Transaction;

use strict;
use warnings;

use constant {
	SIGHASH_ALL => 0x00000001, # <--- this is the default
	SIGHASH_NONE => 0x00000002,
	SIGHASH_SINGLE => 0x00000003,
	SIGHASH_FORKID_UAHF => 0x00000040,
	SIGHASH_ANYONECANPAY => 0x00000080,
	
	OP_PUSHDATA1 => 0x4c,
	OP_PUSHDATA2 => 0x4d,
	OP_PUSHDATA4 => 0x4e,
	
    SCRIPT_VERIFY_NONE      => 0,
    SCRIPT_VERIFY_P2SH      => 1,
    SCRIPT_VERIFY_STRICTENC => 2,
    SCRIPT_VERIFY_DERSIG    => 4,
    SCRIPT_VERIFY_LOW_S     => 8,
    SCRIPT_VERIFY_NULLDUMMY => 16,
    SCRIPT_VERIFY_SIGPUSHONLY => 32,
    SCRIPT_VERIFY_MINIMALDATA => 64,
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS => 128,
    SCRIPT_VERIFY_CLEANSTACK => 256,
    SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY => 512,
    SCRIPT_VERIFY_CHECKSEQUENCEVERIFY => 1024,
	SCRIPT_ENABLE_SIGHASH_FORKID =>  65536
};


=head1 NAME

CBitcoin::Transaction - A wrapper for transactions.

=cut

use CBitcoin;
use CBitcoin::Script;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Utilities;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Transaction::VERSION = $CBitcoin::VERSION;

DynaLoader::bootstrap CBitcoin::Transaction $CBitcoin::VERSION;

@CBitcoin::Transaction::EXPORT = ();
@CBitcoin::Transaction::EXPORT_OK = ();

=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

our $default_version = 1;
our $default_locktime = 0;


our $PARAM_UAHF_BOOL = 'uahf boolean';

our $flagmap = {
   NONE      => SCRIPT_VERIFY_NONE,
   P2SH      => SCRIPT_VERIFY_P2SH,
   STRICTENC => SCRIPT_VERIFY_STRICTENC,
   DERSIG    => SCRIPT_VERIFY_DERSIG,
   LOW_S     => SCRIPT_VERIFY_LOW_S,
   NULLDUMMY => SCRIPT_VERIFY_NULLDUMMY,
   SIGPUSHONLY => SCRIPT_VERIFY_SIGPUSHONLY,
   MINIMALDATA => SCRIPT_VERIFY_MINIMALDATA,
   DISCOURAGE_UPGRADABLE_NOPS => SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS,
   CLEANSTACK => SCRIPT_VERIFY_CLEANSTACK,
   CHECKLOCKTIMEVERIFY => SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY,
   CHECKSEQUENCEVERIFY => SCRIPT_VERIFY_CHECKSEQUENCEVERIFY
};

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
	
	if($CBitcoin::chain eq CBitcoin::CHAIN_UAHF){
		$this->{$PARAM_UAHF_BOOL} = 1;
	}
	
	
	
	return $this;
}

=pod

---++ deserialize($serialized_tx,\@scriptPubs,\@amounts,'uahf')


Get a hash back, not a blessed object.

version
inputs => [..]
outputs => [..]
locktime

input = {prevHash, prevIndex, script, sequence}
output = {value, script}

If deserializing a raw transaction, please provide @scriptPubs that correspond with the inputs.


=cut

sub deserialize{
	my ($package,$data,$script_pubs,$input_amounts,$chain_type) = @_;
		
	$script_pubs //= [];
	if(
		defined $input_amounts && ref($input_amounts) eq 'ARRAY'
		&& scalar(@{$script_pubs}) != scalar(@{$input_amounts})
	){
		die "input amounts not equal to script pubs";
	}
	elsif(defined $input_amounts  && ref($input_amounts) ne 'ARRAY'){
		die "input amounts not an array";
	}
	else{
		$input_amounts = [];
	}

	
	
	my $this = picocoin_tx_des($data);
	bless($this,$package);
	return undef unless $this->{'success'};
	
	if(defined $chain_type && $chain_type eq 'uahf'){
		$this->{$PARAM_UAHF_BOOL} = 1;
	}
	
	$this->{'inputs'} = [];
	my $i = 0;
	
	foreach my $in (@{$this->{'vin'}}){
		$in->{"prevHash"} = join '', reverse split /(..)/, substr($in->{"prevHash"},0,64);
		
		my $input;
		
		# must have script_pub
		if(defined $in->{"scriptSig"}){
			$input = CBitcoin::TransactionInput->new({
				'prevOutHash' => pack('H*',$in->{"prevHash"})
				,'prevOutIndex' => $in->{"prevIndex"}
				,'scriptSig' => $in->{"scriptSig"}
			});
		}
		elsif(0 < scalar(@{$input_amounts})){
			$input = CBitcoin::TransactionInput->new({
				'prevOutHash' => pack('H*',$in->{"prevHash"})
				,'prevOutIndex' => $in->{"prevIndex"}
				,'script' => $script_pubs->[$i]
				,'input_amount' => $input_amounts->[$i]
			});
		}
		else{
			$input = CBitcoin::TransactionInput->new({
				'prevOutHash' => pack('H*',$in->{"prevHash"})
				,'prevOutIndex' => $in->{"prevIndex"}
				,'script' => $script_pubs->[$i]
			});			
		}
		
		push(@{$this->{'inputs'}},$input);
		$i+=1;
	}

	delete $this->{'vin'};
	
	$this->{'outputs'} = [];
	
	foreach my $in (@{$this->{'vout'}}){
		#warn "tx output script=[".unpack('H*',$in->{"script"})."]\n";
		#warn "serialize(".unpack('H*',CBitcoin::Script::serialize_script(
		#	CBitcoin::Script::deserialize_script($in->{"script"})
		#)).")\n";
		push(@{$this->{'outputs'}},CBitcoin::TransactionOutput->new({
			'script' => CBitcoin::Script::deserialize_script($in->{"script"}) 
			,'value' => $in->{"value"}
		}));
	}
	delete $this->{'vout'};
	
	die "no sha256" unless defined $this->{'sha256'} && 0 < length($this->{'sha256'});
	
	$this->{'sha256'} = join '', reverse split /(..)/, $this->{'sha256'};
	$this->{'hash'} = pack('H*',$this->{'sha256'});
	
	delete $this->{'sha256'};
	
	$this->{'serialized full'} = $data;
	
	return $this;
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

=item hash_type

---++ hash_type(SIGHASH_ALL)

Figure out if we are on a fork, if so, provide the fork id.

=cut

sub hash_type($$){
	my ($this,$sigtype) = @_;
	
	my $ans = $sigtype;
	if($this->{$PARAM_UAHF_BOOL}){
		$ans = $ans | SIGHASH_FORKID_UAHF;
	}
	return $ans;
}

=pod

---++ flag_type

=cut

sub flag_type{
	my ($this,$flag,$script) = @_;
	
	$flag //= SCRIPT_VERIFY_NONE;

	if(defined $script && CBitcoin::Script::whatTypeOfScript($script) eq 'multisig'){
		$flag = $flag | SCRIPT_VERIFY_P2SH;
	}
	
	
	if($this->{$PARAM_UAHF_BOOL}){
		$flag = $flag | SCRIPT_VERIFY_STRICTENC;
		$flag = $flag | SCRIPT_ENABLE_SIGHASH_FORKID;
	}
	
	return $flag;
	
}

=pod

---++ addRedeemScript($input_index,$script)

This adds the redeem script to the end of the stack. (scriptSig in picocoin parlance)

=cut

sub add_redeem_script {
	my $this = shift;
	
}


=pod

---++ add_output($tx_out)

=cut

sub add_output($$){
	my ($this,$output) = @_;
	die "no output" unless defined $output && ref($output) =~ m/Output/;
	$this->{'outputs'} //= [];
	push(@{$this->{'outputs'}},$output);
	return scalar(@{$this->{'outputs'}});
}

=pod

---++ randomize()

To preserve privacy, randomize outputs so people cannot gues which output is change and which is sending money.

=cut

sub randomize($){
	my $this = shift;
	CBitcoin::Utilities::fisher_yates_shuffle($this->{'inputs'});
	CBitcoin::Utilities::fisher_yates_shuffle($this->{'outputs'});
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

---++ serialize($raw_bool,$flush_bool)

Raw means there are no script sigs.  Flush means to force reserialization.

=cut

sub serialize {
	my ($this,$raw_bool,$flush_bool) = @_;
	
	if($raw_bool && !$flush_bool && defined $this->{'serialized raw'}){
		return $this->{'serialized raw'};
	}
	elsif(!$raw_bool && !$flush_bool && defined $this->{'serialized full'}){
		return $this->{'serialized full'};
	}
	
	my $data = pack('l',$this->version);
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfInputs);
	for(my $i=0;$i<$this->numOfInputs;$i++){
		$data .= $this->input($i)->serialize($raw_bool);
	}
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfOutputs);
	for(my $i=0;$i<$this->numOfOutputs;$i++){
		#warn "serialization output value=".$this->output($i)->value."\n";
		$data .= $this->output($i)->serialize();
	}
	
	$data .= pack('L',$this->lockTime);
	
	# TODO: check if fixing this bug affects doing transactions!
	if($raw_bool && !(defined $this->{'serialized raw'})){
		$this->{'serialized raw'} = $data;
	}
	elsif(!$raw_bool){
		$this->{'serialized full'} = $data;
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
	my ($this,$data,$flags,$hashtype) = @_;
	
	#$flags //= SCRIPT_VERIFY_STRICTENC;
	$flags //= SCRIPT_VERIFY_NONE;
	$hashtype //=SIGHASH_ALL;
	
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
		#warn "i=$i pre validate\n";
		$bool = picocoin_tx_validate_input(
			$i
			, CBitcoin::Script::serialize_script($this->input($i)->script()) # scriptPubKey
			, $txdata  # includes scriptSig
			, $this->flag_type($flags,$this->input($i)->script()) # sigvalidate
			, $this->hash_type($hashtype) # default;
			, pack('q',$this->input($i)->input_amount())
		);
		#warn "i=$i post validate with bool=$bool\n";
		#return 0 unless $bool;
	}
	return $bool;
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
		#die "bad signature" unless defined $sigs[-1] && 0 < length($sigs[-1]);
		$txraw = picocoin_tx_sign_p2pkh(
			$key->serialized_private(),
			CBitcoin::Script::serialize_script($this->input($i)->script()),
			$txdata,
			$i,
			$this->hash_type(SIGHASH_ALL),
			$this->input($i)->input_amount
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
		$this->hash_type(SIGHASH_ALL),
		$this->input($i)->input_amount()
	);
	die "bad signature" unless defined $txraw && 0 < length($txraw);
	return $txraw;
	
}

=pod

---++ assemble_p2p($i,$key)

=cut

sub assemble_p2p {
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
	


	$txraw = picocoin_tx_sign_p2p(
		$key->serialized_private(),
		CBitcoin::Script::serialize_script($this->input($i)->script()),
		$txdata,
		$i,
		$this->hash_type(SIGHASH_ALL),
		$this->input($i)->input_amount()
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


=pod

---++ txfee($size)

70 satoshis/byte.

=cut

sub txfee{
	my $size = shift;
	die "bad size" unless defined $size && $size =~ m/^(\d+)$/ && 0 < $size;
	my $fee = 70;

	return $size*$fee;
}


=head1 SYNOPSIS

  use CBitcoin;
  use CBitcoin::Transaction;
  
  
=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/favioflamingo/libcbitcoin-perl>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::Transaction


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

1; # End of CBitcoin::Transaction
