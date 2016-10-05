package CBitcoin::Tree;

use utf8;
use strict;
use warnings;

use constant {
	MAXACCOUNTS => 1024
	,MINTXAMOUNT => 800 # 800 satoshis are the minimum size before tx is considered dust

	,ROOT => 0
	,CHANNEL => '1|1'
	,CASH => '1/1'
	,SERVERS => '1/2'
	,USERS => '1/3'
};

use List::Util qw(shuffle);
use CBitcoin::Script;
use CBitcoin::Tree::Node;
use Digest::MD5 qw(md5);








our $constants;

BEGIN{
	$constants = {
		'to' => {
			'ROOT' => ROOT
			,'CHANNEL' => CHANNEL
			,'CASH' => CASH
			,'SERVERS' => SERVERS
			,'USERS' => USERS
		}
	};
	foreach my $key (keys %{$constants->{'to'}}){
		$constants->{'from'}->{$constants->{'to'}->{$key}} = $key; 
	}
}


=pod

---+ constructors

=cut

=pod

---++ new

=cut

sub new {
	my $package = shift;

	my $this = {};
	bless($this,$package);

	$this->init(@_);
	
	return $this;
}



=pod

---++ init($options)

Set up the linked nodes.

=cut

sub init{
	my $this = shift;


	$this->{'max i'} = MAXACCOUNTS;

	$this->{'dict'} = {};

	$this->{'tree'} = CBitcoin::Tree::Node->new(0);

	$this->{'txs'} = {};
	$this->{'tx ordering'} = [];

	my $schema = shift;
	if(defined $schema && ref($schema) eq 'ARRAY'){
		foreach my $s (@{$schema}){
			$this->node_create_by_name($s);
		}
	}
	else{
		die "no schema";
	}

	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'tree'});
	#print "Tree=$xo\n";
	$this->max_i(MAXACCOUNTS, MAXACCOUNTS + 40);
}

=pod

---+ getters/setters

=cut

=pod

---++ dict

=cut

sub dict{
	return shift->{'dict'};
}

=pod

---+ utilities

=cut

=pod

---++ dict_check($item)

Check an item to see if is in the dictionary

=cut

sub dict_check{
	my ($this,$item) = @_;
	return 0 unless defined $item && 0 < length($item);
	
	my $h = md5($item);
	return (
		defined $this->{'dict'}->{substr($h,0,8)} && defined $this->{'dict'}->{substr($h,0,8)}->{substr($h,8)} 
	) ? 1 : 0;
}

=pod

---++ dict_node($item)->[$node,$hardbool,$index]

Fetch the node that corresponds to the item.

=cut

sub dict_node{
	my ($this,$item) = @_;
	return 0 unless $this->dict_check($item);
	
	my $h = md5($item);
	my ($p1,$p2) = (substr($h,0,8),substr($h,8));
	foreach my $ref (@{$this->{'dict'}->{$p1}->{$p2}}){
		# node, hardbool,index
		my $hdkey = $ref->[0]->hdkey->deriveChild($ref->[1],$ref->[2]);
		return [$ref->[0],$ref->[1],$ref->[2]] if $hdkey->publickey eq $item || $hdkey->ripemdHASH160 eq $item;
	}
	
	die "should not be here!";
}

=pod

---++ parse($path_string)

Parse a string like "ROOT|CHANNEL_1" to ["/ROOT","|CHANNEL_1"]

=cut

sub parse{
	my ($this,$pString) = @_;
	return undef unless defined $pString && 0 < length($pString);

	foreach my $key (keys %{$constants->{'to'}}){
		my $value = $constants->{'to'}->{$key};
		$pString =~ s/$key/$value/g;
	}	
	#print "P=$pString\n";
	# create root node
	my @results;

	foreach my $y (split(/(\/)/,$pString)){
		next if $y eq '/';
		my @z1 = split(/(\|)/,$y);
		my @b = ('/'.shift(@z1));
		foreach my $z (@z1){
			next if $z eq '|';
			push(@b,'|'.$z);
		}
		push(@results,@b);
	}

	return \@results;
}

=pod

---++ node_create_by_name

=cut

sub node_create_by_name {
	my $this = shift;


	my $r = $this->parse(shift);
	return undef unless defined $r && ref($r) eq 'ARRAY' && 0 < scalar(@{$r});


	my $node = $this->{'tree'};

	my $depth = 0;
	foreach my $n (@{$r}){
		$depth += 1;
		if($n =~ m/^(\||\/)(\d+)$/){
			# symbol, index
			my @x = ($1,$2);

			if(1 < $depth){
				my $nextnode = $node->next($x[1],$x[0]);
				unless(defined $nextnode){
					$nextnode = CBitcoin::Tree::Node->new($x[1]);
					$node->append($nextnode,$x[0]);
				}
				$node = $nextnode;
			}
		}
		else{
			die "bad feed!(n=$n)";
		}
	}
}

=pod

---++ node_get_by_path($path)

[['ROOT','|',0],['CHILD','/',33]]

/ means hard child.  | means soft child.

=cut

sub node_get_by_path {
	my $this = shift;
	my $path = shift;
	my $r = $this->parse($path);
	return undef unless defined $r;

	my $node = $this->{'tree'};
	# first node is always the ROOT
	shift(@{$r});

	while(my $n = shift(@{$r})){
		if($n =~ m/^(\||\/)(\d+)$/){
			# symbol, index
			$node = $node->next($2,$1);
		}
		else{
			die "path error";
		}
	}
	#die "not defined $node" unless defined $node;
	return $node;
}

=pod

---++ hdkey_set("path",$xprv)

=cut

sub hdkey_set{
	my ($this,$path,$cbhd) = @_;
	my $node = $this->node_get_by_path($path);
	return undef unless defined $node;

	# set the hdkey on all lower keys
	$node->hdkey($cbhd);
	
}


=pod

---+ exporting

=cut

=pod

---++ export($path,$type)

=cut

sub export {
	my ($this,$path,$type) = @_;
	my $node = $this->node_get_by_path($path);
	die "no node where p=$path" unless defined $node;
	return undef unless defined $type;

	return undef unless defined $node->hdkey();
	
	if($type eq 'address'){
		return $node->hdkey->address();
	}
	elsif($type eq 'ripemdHASH160'){
		return $node->hdkey->ripemdHASH160();
	}
	else{
		die "bad type";
	}
}

=pod

---++ deposit($m,$n,@paths)

Make multisignature address.

=cut

sub deposit {
	my $this = shift;
	my ($m) = (shift);
	my @paths = @_;
	my $n = scalar(@paths);
	
	if($n == 0){
		my $node = $this->node_get_by_path($m);
		my $hdkey = $node->hdkey;
		return $hdkey->deriveChild($node->hard,$node->sub_index(-1))->address();
	}
	else{
		die "bad m" unless defined $m && defined $m && $m =~ m/^\d+$/ && 0 < $m && $m <= $n;

		my $getsub = sub{
			my $p1 = shift;
			my $node = $this->node_get_by_path($p1);
			die "no path for $p1" unless defined $node;
			#return $node;
			#return '0x'.unpack('H*',$node->hdkey->ripemdHASH160());
			return $node->hdkey->publickey();
		};

		my @pubs = map { $getsub->($_) } @paths;

		return CBitcoin::Script::script_to_address(
			CBitcoin::Script::multisig_p2sh_script($m,$n,@pubs)
		);
	}
}



=pod

---+ accounting

=cut

=pod

---++ balance($type)

Do a recursive check for all balances

=cut

sub balance {
	my ($this,$type) = @_;
	my $node = $this->{'tree'};
	return $node->balance_recursive($type);
}

=pod

---++ max_i($i)

$i can be either an absolute number or relative (+3).

=cut

sub max_i {
	my ($this,$i) = @_;

	if(defined $i && $i =~ m/^\+(\d+)$/){
		return $this->max_i($this->{'max i'} + $1);
	}


	if(defined $i && $i =~ m/^(\d+)$/){
		$i = $1;
	#	MAXACCOUNTS;
		if($this->{'max i'} < $i){
			#warn "generating addresses";
			$this->{'tree'}->max_i_update($this->{'dict'},$this->{'max i'},$i);
			$this->{'max i'} = $i;
		}
		else{
			#warn "doing nothing with i=$i";
		}
		return $this->{'max i'};
	}
	elsif(defined $i){
		die "bad i";
	}
	else{
		return $this->{'max i'};
	}
}

=pod

---++ node_find_by_hash($item)->[[$node,$hardbool,$index],...]

Look thru the dictionary, find nodes relavent to item.

=cut

sub node_find_by_hash{
	my ($this,$hash) = @_;
	my $ans = [];
	return $ans unless defined $hash && 0 < length($hash);
	$hash = md5($hash);
	my ($p1,$p2) = (substr($hash,0,8),substr($hash,8));
	if(
		defined $this->{'dict'}->{$p1}
		&& defined $this->{'dict'}->{$p1}->{$p2}
	){
		$ans = $this->{'dict'}->{$p1}->{$p2};
	}
	
	return $ans;
}


=pod

---++ txoutput_get($hash,$i)

Given an input with a prevHash and prevIndex, get the corresponding output so that we can confirm the scriptPub and value.

=cut

sub txoutput_get{
	my ($this,$hash,$i) = @_;
	return undef unless defined $hash && defined $i && $i =~ m/^(\d+)$/;
	
	my $tx = $this->{'txs'}->{$hash};
	return undef unless defined $tx && $i < $tx->numOfOutputs;
	
	return $tx->output($i);
}

=pod

---++ tx_add

=cut

sub tx_add {
	my $this = shift;
	my @done = map {$this->tx_add_single($_)} @_;
	
}

sub tx_add_single {
	my ($this,$tx) = @_;
	die "not a transaction" unless defined $tx && ref($tx) eq 'CBitcoin::Transaction';

	my $addbool = 0;
	my $txhash = $tx->hash;
	for(my $i=0;$i<$tx->numOfInputs;$i++){
		$addbool = 1 if $this->tx_add_singleinput($tx->input($i),$txhash,$i);
	}

	for(my $i=0;$i<$tx->numOfOutputs;$i++){
		$addbool = 1 if $this->tx_add_singleoutput($tx->output($i),$txhash,$i);
	}

	if($addbool){
		$this->{'txs'}->{$txhash} = $tx;
		push(@{$this->{'tx ordering'}},$tx);
	}

	return $addbool;
}

=pod

---+++ single input

Decreases balances.

=cut

sub tx_add_singleinput{
	my ($this,$input) = @_;
#	warn "input=$input";
	
	my $scriptSig = $input->scriptSig;
	# parse script sig?
	my @s = split(' ',CBitcoin::Script::deserialize_script($scriptSig));
	
	my $n = scalar(@s);
	
	my $ref;
	if($n == 2 && substr($s[0],0,2) eq '0x' && substr($s[1],0,2) eq '0x'){
		# my ($sig,$pubkey) = ($s[0],$s[1]);
		my $pubkey = pack('H*',substr($s[1],2));
		$ref = $this->dict_node($pubkey);
		return 0 unless $this->dict_check($pubkey);
	}
	elsif($n == 2){
		warn "I do not know what we have";
		return 0;
	}
	else{
		# TODO: check for multisig
		return 0;
	}
	
	# at this point, this input belongs to us
	# $ref = [[$node,$hardbool,$index],...]
	# find the correct node
	
	
	# find the script/value from previous transaction, adjust balance of node
	
	
	return 1;
}

=pod

---+++ single output

Increases balances and decreases balances.

=cut

sub tx_add_singleoutput{
	my ($this,$output,$hash,$i) = @_;
	
	my $script = CBitcoin::Script::deserialize_script($output->script);
	
	my $type = CBitcoin::Script::whatTypeOfScript($script);
	my @s = split(' ',$script);
	my $value = $output->value;
	
	# p2sh, p2pkh, multisig
	my $node;
	if($type eq 'p2pkh'){
		# we have: OP_DUP OP_HASH160 0x3dbcec384e5b32bb426cc011382c4985990a1895 OP_EQUALVERIFY OP_CHECKSIG
		my $p2pkhash = pack('H*',substr($s[2],2));

		if($this->dict_check($p2pkhash)){
			my $ref = $this->dict_node($p2pkhash);
			$node = $ref->[0];
			
			my $t_in = CBitcoin::TransactionInput->new({
				'prevOutHash' => $hash #should be 32 byte hash
				,'prevOutIndex' => $i
				,'script' => CBitcoin::Script::deserialize_script($output->script) # scriptPubKey (after being turned into p2sh)
			});
			
			# add output to database
			$node->input_add_p2pkh($t_in,$output->value,$ref->[1],$ref->[2]);			
		}

	}
	
	return (defined $node) ?  1 : 0;
}

=pod

---++ cash_move($from,$to,$amount)

Move cash from one node to another node.

=cut

sub cash_move{
	my ($this,$from_path,$to_path,$destination_amount) = @_;
	my $from_node = $this->node_get_by_path($from_path);
	return undef unless defined $from_node;
	my $to_node = $this->node_get_by_path($to_path);
	return undef unless defined $to_node;
	return undef unless defined $destination_amount && $destination_amount =~ m/^(\d+)$/;
	$destination_amount = $1;
	
	my $destination_address = $this->deposit($to_path);
	
	### at this point, we have:  ($destination_amount,$destination_address,$from_path) ####
	
	# size of tx
	# for each outpoint, ?
	my ($numOfInputs,$numOfOutputs) = (3,3);
	
	my $fee = CBitcoin::Transaction::txfee(4 + 1 + 41*$numOfInputs + 1 + 9*$numOfOutputs + 4);
	
	# find the balance
	my $balance = $from_node->balance();
	
	# need to calculate change address amount
	my $change_amount = $balance - $fee - $destination_amount;
	return undef unless MINTXAMOUNT <= $change_amount;
	my $change_address = $this->deposit($from_path);
	
	
	####### construct the transaction inputs ##########
	# find [[$input,$value,$hdkey],...] for outputs
	my $output_ref = $from_node->input_use();
	my @ins;
	my $j = 0;
	my ($N_p2pkh,$N_p2sh) = (scalar(@{$output_ref->{'p2pkh'}}),scalar(@{$output_ref->{'p2sh'}}));
	my @ins_outputs;
	# single hdkey address
	for(my $i=0;$i<$N_p2pkh;$i++){
		push(@ins,$output_ref->{'p2pkh'}->[$i]->[0]);
		push(@ins_outputs,['p2pkh',$i,$j]);
		$j++;
	}
	# multisig address
	for(my $i=0;$i<$N_p2sh;$i++){
		push(@ins,$output_ref->{'p2sh'}->[$i]->[0]);
		push(@ins_outputs,['p2sh',$i,$j]);
		$j++;
	}
	my @ins_mapping = shuffle((0..($N_p2pkh + $N_p2sh - 1)));
	@ins = map { $ins[$_] } @ins_mapping;
	@ins_outputs = map { $ins_outputs[$_] } @ins_mapping;
	
	########## construct transaction outputs #############
	my @outs;
	# make the change address output
	push(@outs, CBitcoin::TransactionOutput->new({
		'value' => $change_amount
		,'script' => CBitcoin::Script::address_to_script($change_address)
	}));
	# make the destination address output
	push(@outs, CBitcoin::TransactionOutput->new({
		'value' => $destination_amount
		,'script' => CBitcoin::Script::address_to_script($destination_address)	
	})); 
	
	@outs = shuffle(@outs);
	
	######### construct raw transaction ############
	my $tx = CBitcoin::Transaction->new({
		'inputs' => \@ins, 'outputs' => \@outs
	});
	
	
	######### sign transaction ########
	my $txdata;
	# do the single address signatures first
	for(my $i=0;$i<scalar(@ins);$i++){
		my $xref = $ins_outputs[$i];
		if($xref->[0] eq 'p2pkh'){
			$txdata = _cash_move_txsign_p2pkh(
				$output_ref->{$xref->[0]}->[$xref->[1]]
				,$tx,$txdata
				,$xref->[2]
			);
		}
		elsif($xref->[0] eq 'p2sh'){
			$txdata = _cash_move_txsign_p2sh(
				$output_ref->{$xref->[0]}->[$xref->[1]]
				,$tx,$txdata
				,$xref->[2]
			);			
		}
		else{
			die "bad type";
		}
	}
	
	
	die "bad signatures" unless $tx->validate_sigs($txdata);
	
	return $txdata;
}

sub _cash_move_txsign_p2pkh {	
	my ($output_ref,$tx,$txdata,$i) = @_;
	# index, hdkey, txdata
	return $tx->assemble_p2pkh($i,$output_ref->[2],$txdata);
}

sub _cash_move_txsign_p2sh {
	my ($output_ref,$tx,$txdata,$i) = @_;
	# 'p2sh' => [[$input,$value,$m,$hdkey1,$hdkey2,....],...]
	
	# $output_ref->{'p2sh'}->[$i]->[2]
	die "cannot do multisignatures yet";
}

1;