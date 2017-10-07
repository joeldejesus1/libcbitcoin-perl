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

=header1 Constructors

=item new
	
	use CBitcoin;
	use CBitcoin::Transaction;
	
	$CBitcoin::network_bytes = CBitcoin::TESTNET;
	$CBitcoin::chain = CBitcoin::CHAIN_LEGACY;

	my $tx = CBitcoin::Transaction->new(
		'inputs' => \@txinputs, 'outputs' => \@txoutputs
	);


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

=item deserialize

	my $tx = CBitcoin::Transaction->deserialize($serialized_tx,\@scriptPubs,\@amounts);
	die "failed to parse" unless defined $tx;
	
If deserializing a raw transaction, please provide @scriptPubs that correspond with the inputs.  If you are on the UAHF chain, then you need to also provide the amounts (in satoshi) that correspond to all inputs.


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

Returns the lockTime on the transaction.

=cut

sub lockTime {
	return shift->{'lockTime'};
}

=item version

=cut

sub version {
	return shift->{'version'};
}

=item hash

Returns the double sha256 hash of the transaction, which also functions a sort of transaction id.  However, please do not use this as an id when accounting for real money.

=cut

sub hash {
	return shift->{'hash'};
}

=item hash_type B<$tx->hash_type(SIGHASH_ALL) >

This hash is unrelated to the hash() subroutine.  This one is related to what parts of the transaction do signatures correspond to.  There is no need to mess with this subroutine unless you know what you are doing.  

=cut

sub hash_type($$){
	my ($this,$sigtype) = @_;
	
	my $ans = $sigtype;
	if($this->{$PARAM_UAHF_BOOL}){
		$ans = $ans | SIGHASH_FORKID_UAHF;
	}
	return $ans;
}

=item flag_type

Similar to hash_type(), this sorts out what flags are used when evaluating input scripts.  This is used in validate_sigs().

=cut

sub flag_type{
	my ($this,$flag,$script) = @_;
	
	$flag //= SCRIPT_VERIFY_NONE;

	if(
		defined $script && 
		(
			CBitcoin::Script::whatTypeOfScript($script) eq 'multisig'
			|| CBitcoin::Script::whatTypeOfScript($script) eq 'p2sh'
		)
		
	){
		$flag = $flag | SCRIPT_VERIFY_P2SH;
	}
	
	
	if($this->{$PARAM_UAHF_BOOL}){
		$flag = $flag | SCRIPT_VERIFY_STRICTENC;
		$flag = $flag | SCRIPT_ENABLE_SIGHASH_FORKID;
	}
	
	return $flag;
	
}

=head2 Handling Inputs/Outputs

Inputs contain the contract language that determines who has the right to claim the funds stored on the input balance.  The outputs contain the addresses and amounts being spent.  The addresses are typically references to the contract, not the contract itself.  The contract (in P2SH scripts) are referred to as redeem scripts.

=item B<$tx->add_redeem_script($input_index,$script)>

For p2sh transaction inputs, you need the redeem script in order to claim the funds.  Use this subroutine to add the redeem script to the corresponding transaction input.  The redeem script must be in human readable format (deserialized), not serialized binary format.

=cut

sub add_redeem_script($$$){
	my ($this,$nIndex,$redeem_script) = @_;
	
	die "bad index" unless defined $nIndex && $nIndex =~ m/^(\d+)$/
		&& 0 <= $nIndex && $nIndex < $this->numOfInputs;
	
	die "no script" unless defined $redeem_script && 0 < length($redeem_script);
	
	my $input = $this->input($nIndex);
		
	$this->input($nIndex)->redeem_script($redeem_script);
	
}


=item B<add_output($tx_out)>

Do not use this subroutine.  All outputs have to be supplied in the constructor.

=cut

sub add_output($$){
	my ($this,$output) = @_;
	die "no output" unless defined $output && ref($output) =~ m/Output/;
	$this->{'outputs'} //= [];
	push(@{$this->{'outputs'}},$output);
	return scalar(@{$this->{'outputs'}});
}

=item B<randomize()>

To preserve privacy, randomize outputs so people cannot gues which output is change and which is sending money.  Do not use this subroutine directly.

=cut

sub randomize($){
	my $this = shift;
	CBitcoin::Utilities::fisher_yates_shuffle($this->{'inputs'});
	CBitcoin::Utilities::fisher_yates_shuffle($this->{'outputs'});
}

=item numOfInputs

Returns the number of inputs in the transaction.

=cut

sub numOfInputs {
	return scalar(@{shift->{'inputs'}});
}

=item B<$tx->input(2)>

Returns the transaction input corresponding to the index number in the argument.

=cut

sub input {
	return shift->{'inputs'}->[shift];
}

=item numOfOutputs

Returns the number of transaction outputs.

=cut

sub numOfOutputs {
	return scalar(@{shift->{'outputs'}});
}

=item B<$tx->output(2) >

Returns the transaction output corresponding to the index number in the argument.

=cut

sub output {
	return shift->{'outputs'}->[shift];
}

=header2 Transaction Data

=item B<$tx->serialize($raw_bool,$flush_bool)>

Raw means there are no script sigs.  Flush means to force reserialization (includes script sigs).

To get a serialized raw transaction:
	my $rawtx = $tx->serialize(1);

Do not use this subroutine to get a fully signed transaction.

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


=item validate

https://en.bitcoin.it/w/images/en/7/70/Bitcoin_OpCheckSig_InDetail.png

This subroutine is obsolete.

=cut

#sub validate_syntax{
#	die "should not be here";
#	my ($this,$data,$full) = @_;
#	die "no data provided" unless defined $data && 0 < length($data);
#
#	if($full){
#		
#		return $this->validate_full($data,@_);
#	}
#	else{
#		return picocoin_tx_validate($data);
#	}
#	
#}

=item B<$tx->validate_sigs($txdata) >

https://en.bitcoin.it/w/images/en/7/70/Bitcoin_OpCheckSig_InDetail.png

SCRIPT_VERIFY_NONE -> 1
SCRIPT_VERIFY_STRICTENC -> 2
SCRIPT_VERIFY_P2SH -> 3
SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_STRICTENC -> 4

Validate a serialized transaction.  The $txdata is a product of signing a transaction.  We need to deserialize the transaction first and add in the script pubs (the contract language) for the transaction inputs.

=cut

sub validate_sigs {
	my ($this,$data,$flags,$hashtype) = @_;
	
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
		#warn "validation script:".$this->input($i)->script()."\n";
		$bool = picocoin_tx_validate_input(
			$i
			, CBitcoin::Script::serialize_script($this->input($i)->script()) # scriptPubKey
			, $txdata  # includes scriptSig
			, $this->flag_type($flags,$this->input($i)->script()) # sigvalidate
			, $this->hash_type($hashtype) # default;
			, pack('q',$this->input($i)->input_amount())
		);
		#warn "i=$i post validate with bool=$bool\n";
		return 0 unless $bool;
	}
	return $bool;
}


=header2 Making Signatures

=item B<$tx->assemble_multisig_p2sh($i,$n,$txraw,@keys)>

The keys are in binary form, as is the transaction data.  The following is an example of how to use it.


	# see CBitcoin::CBHD;
	my $root = CBitcoin::CBHD->generate();

	# set the chain
	$CBitcoin::chain = CBitcoin::CHAIN_UAHF;


	my @keys = (
		$root->deriveChild(1,1),$root->deriveChild(1,2)
	);
	
	
	# the prevout hash.  the prevout index is below.
	# got these from a block explorer, but we have to reverse the bytes
	my @hashes = (
		'6105e342232a9e67e4fa4ee0651eb8efd146dc0d7d346c788f45d8ad591c4577'
	);
	
	# multisig_p2sh_script($m,$n,@pubksy)
	my $multisig_input = CBitcoin::Script::multisig_p2sh_script(2,2,
		$root->deriveChild(1,1)->publickey(),
		$root->deriveChild(1,2)->publickey()
	);
	my $p2sh_input = CBitcoin::Script::script_to_p2sh($multisig_input);

	my @ins = (
		# input amount = 0.01394 BTC 
		CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',join('',reverse($hashes[0] =~ m/([[:xdigit:]]{2})/g) )  ) 
			,'prevOutIndex' => 1
			,'script' =>  $p2sh_input 
			,'input_amount' => int(0.01394 * 100_000_000)
		}),
	);
	my $balance = int( (0.01394) * 100_000_000);
	my $fee = int(0.0001 * 100_000_000);
	
	my @outs = (
		CBitcoin::TransactionOutput->new({
			'script' => CBitcoin::Script::address_to_script($root->deriveChild(1,3)->address())
			,'value' => ($balance - $fee)
		})
	);
	
	my $tx = CBitcoin::Transaction->new({
		'inputs' => \@ins, 'outputs' => \@outs
	});
	# need the redeem script in order to do the signature.
	$tx->add_redeem_script(0,$multisig_input);

	
	my $txdata = $tx->assemble_multisig_p2sh(
		0
		,2 # total number of pub keys
		,undef
		,$root->deriveChild(1,1),$root->deriveChild(1,2)
	);

	ok($tx->validate_sigs($txdata),'good tx with multisig uahf');

=cut

sub assemble_multisig_p2sh {
	my ($this,$i,$n,$txraw) = (shift,shift,shift,shift);
	
	my @keys = @_;
	die "bad keys" unless 0 < scalar(@keys);
	
	# do some testing
	die "bad index" unless defined $i && 0 <= $i && $i < $this->numOfInputs();
	
	
	my $txdata;
	if(defined $txraw && 0 < length($txraw)){
		$txdata = $txraw;
	}
	else{
		$txdata = $this->serialize();
	}
	
	# make sure we start ScriptSig with OP_0 
	$txdata = picocoin_tx_push_p2sh_op_false($i,$txdata);

	my $ser_script_pub = CBitcoin::Script::serialize_script($this->input($i)->script());
	die "no redeem script in transaction input" unless defined $this->input($i)->redeem_script()
		&& 0 < length($this->input($i)->redeem_script());
	my $ser_redeem_script = CBitcoin::Script::serialize_script($this->input($i)->redeem_script());

	
	foreach my $key (@keys){
		# push Sig onto scriptSig.
		# get back {'sig' => $signature, 'success' => 0/1, 'tx' => $txdata}
		my $xref = picocoin_tx_push_signature(
			$key->serialized_private(),
			$ser_redeem_script,
			$txdata,
			$i,
			$this->hash_type(SIGHASH_ALL),
			$this->input($i)->input_amount
		);
		die "bad signature" unless defined $xref && $xref->{'success'};
		$txdata = $xref->{'tx'};
		
		# my $signature = $xref->{'sig'};
	}
	
	$txdata = picocoin_tx_push_redeem_script($i,$txdata,$ser_redeem_script);
	
	return $txdata;
}


=item B<my $txdata = $tx->assemble_p2pkh($i,$key)>

With a CBHD $key, sign a transaction input.  The serialized transaction including the signature is returned.  This subroutine is for pay to public key hash scripts.

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

=item B<my $txdata = $tx->assemble_p2p($i,$key)>

With a CBHD $key, sign a transaction input.  The serialized transaction including the signature is returned.  This subroutine is for pay to public key scripts.  P2P scripts are usually found in coinbase transactions.  P2PKH is normally.

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

=header2 Utilities

=item B< push_data($data)->$adddata >


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


=item B< txfee($size)>

The default is 70 satoshis/byte.

	$CBitcoin::Transaction::tx_fee = 70;

=cut

our $tx_fee;

BEGIN{
	# set default
	$tx_fee = 70;
}

sub txfee{
	my $size = shift;
	die "bad size" unless defined $size && $size =~ m/^(\d+)$/ && 0 < $size;

	return $size*$tx_fee;
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

Copyright 2014-2017 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::Transaction
