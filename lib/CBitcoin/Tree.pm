package CBitcoin::Tree;

use utf8;
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock SEEK_END);
	
use constant {
	MAXACCOUNTS => 1024
	,MINTXAMOUNT => 800 # 800 satoshis are the minimum size before tx is considered dust

	,ROOT => 0
	,CHANNEL => '1|1'
	,CASH => '1/1'
	,SERVERS => '1/2'
	,USERS => '1/3'
};

use Data::UUID;
use List::Util qw(shuffle);
use CBitcoin::Script;
use CBitcoin::Tree::Node;
use CBitcoin::Tree::Broadcast;
use Digest::MD5 qw(md5);
use Cwd;







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
	my ($this,$schema,$options) = @_;

	$options //= {};
	die "bad option" unless ref($options) eq 'HASH';

	foreach my $k (keys %{$options}){
		$this->{$k} = $options->{$k};
	}
	
	if(defined $this->{'base directory'}){
		$this->{'base directory'} = CBitcoin::Utilities::validate_filepath($this->{'base directory'});
		die "bad directory" unless defined $this->{'base directory'}; 
	}
	else{
		$this->{'base directory'} = 'db';
	}
	
	$this->{'uuid generator'} = Data::UUID->new;
	$this->{'id'} //= $this->uuid_gen->to_string($this->uuid_gen->create());
	
	$this->init_dirs();
	
	$this->{'max i'} //= MAXACCOUNTS;

	$this->{'dict'} = {};

	$this->{'tree'} = CBitcoin::Tree::Node->new(0,$this->base_dir);

	$this->{'txs'} = {};
	$this->{'tx ordering'} = [];

	
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
	
	
	$this->db_tx_index();
	
	
	
	$this->{'bloom filter'} = CBitcoin::BloomFilter->new({
		'FalsePostiveRate' => 0.001,
		'nElements' => 1000 
	});
}

=pod

---+++ init_dirs

Set up directories to store tree.

=cut


sub init_dirs{
	my ($this) = @_;
	my $basedir = $this->base_dir();
	
	unless(-d $basedir){
		mkdir($basedir);
	}
	mkdir("$basedir/txs");
	mkdir("$basedir/inputs_inflight");
	

	
	
	# create the file handle for locking
	sysopen (my $fh, "$basedir/txs/.lock", O_RDWR|O_CREAT, 0600) || die "cannot open tx db";
	binmode($fh);
	$this->{'tx db lock fh'} = $fh;	
	
	$this->db_tx_lock();
	my $size = (stat("basedir/txs/.lock"))[7];
	$size //= 0;
	if($size == 0){
		
		sysseek($fh,0,0);
		syswrite($fh,pack('l',0));
		$this->{'lock time'} = 0;
		
	}
	else{
		sysseek($fh,0,0);
		my ($n,$buf);
		$n = sysread($fh,$buf,4);
		die "bad lock read" unless $n == 4;
		$this->{'lock time'} = unpack('l',$buf);
	}
	
	$this->db_tx_unlock();
	
	# create the directory for our special tree
	$basedir .= '/trees';
	unless(-d $basedir){
		mkdir($basedir);
	}
	$basedir .= '/'.$this->id;
	unless(-d $basedir){
		mkdir($basedir);
	}
	
	$this->{'base directory'} = $basedir;
}


=pod

---+ getters/setters

=cut

=pod

---++ bloomfilter

=cut

sub bloomfilter{
	return shift->{'bloom filter'};
}

=pod

---++ dict

=cut

sub dict{
	return shift->{'dict'};
}

=pod

---++ tx_fh

=cut

sub tx_fh{
	return shift->{'tx db file handle'};
}

=pod

---++ base_dir

=cut

sub base_dir{
	return shift->{'base directory'};
}

=pod

---++ id

=cut

sub id{
	return shift->{'id'};
}

=pod

---++ uuid_gen

=cut

sub uuid_gen{
	return shift->{'uuid generator'};
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
					$nextnode = CBitcoin::Tree::Node->new($x[1],$this->base_dir);
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

---++ bloomfilter_calculate()

Create a bloom filter.  The hdkeys are 

=cut

sub bloomfilter_calculate{
	my ($this) = @_;
	
	my $bf = CBitcoin::BloomFilter->new({
		'FalsePostiveRate' => 0.001,
		'nElements' => 1000 
	});
	my @refs;
	foreach my $p1 (keys %{$this->{'dict'}}){
		foreach my $p2 (keys %{$this->{'dict'}->{$p1}}){
			my $ref_X = $this->{'dict'}->{$p1}->{$p2};
			next unless 0 < scalar(@{$ref_X});
			foreach my $ref (@{$ref_X}){
				my $hdkey = $ref->[0]->hdkey->deriveChild($ref->[1],$ref->[2]);
				$bf->add_raw($hdkey->ripemdHASH160);
				$bf->add_raw($hdkey->publickey);
			}
			
		}
	}

	$bf->bloomfilter_calculate();
	
	$this->{'bloom filter'} = $bf;
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
		$this->bloomfilter_calculate();
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

---++ tx_add($time,@txdatas)

Use this to add transactions from a block.  Use the block time to timestamp the transactions, not the block height.

=cut

sub tx_add {
	my $this = shift;
	my $time = shift;
	die "bad time" unless defined $time && $time =~ m/^(\d+)$/;
	
	my $time_hex = lc(unpack('H*',pack('l',$time)));
	if($time_hex =~ m/^([0-9a-f]+)$/){
		$time_hex = $1;
	}
	my @txs;
	
	############# Lock DB ###################
	$this->db_tx_lock();
	
	# check to see if another process has added transactions
	push(@txs,$this->db_tx_index());
	
	while(my $txdata = shift(@_)){
		my $tx;
		if(ref($txdata) eq 'CBitcoin::Transaction'){
			$tx = $txdata;
			$txdata = $tx->serialize();
			$this->db_tx_insert($tx);
		}
		elsif($tx = CBitcoin::Transaction->deserialize($txdata)){
			$this->db_tx_insert($tx,$time_hex);
		}
		else{
			warn "failed to get transaction";
			next;
		}
		push(@txs,$tx);
	}
	$this->db_tx_unlock();
	##########################################
	
	while(my $tx = shift(@txs)){
		$this->tx_add_single($tx);
	}
	
}

# only handles inmemory stuff

sub tx_add_single {
	my ($this,$tx) = @_;
	die "not a transaction" unless defined $tx && ref($tx) eq 'CBitcoin::Transaction';
	
	
	my $addbool = 0;
	my $txhash = $tx->hash;
	return 0 if $this->{'txs'}->{$txhash};
	
	my $input_nodes = [];
	for(my $i=0;$i<$tx->numOfInputs;$i++){
		$input_nodes = $this->tx_add_singleinput($tx->input($i),$txhash,$i);
		$addbool = 1 if 0 < scalar(@{$input_nodes});
	}

	for(my $i=0;$i<$tx->numOfOutputs;$i++){
		$addbool = 1 if $this->tx_add_singleoutput($input_nodes,$tx->output($i),$txhash,$i);
	}

	if($addbool){
		$this->{'txs'}->{$txhash} = $tx;
		push(@{$this->{'tx ordering'}},$tx);
	}
	else{
		die "did not add tx";
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
	
	my @nodes;
	my $ref;
	if($n == 2 && substr($s[0],0,2) eq '0x' && substr($s[1],0,2) eq '0x'){
		# my ($sig,$pubkey) = ($s[0],$s[1]);
		my $pubkey = pack('H*',substr($s[1],2));
		if($this->dict_check($pubkey)){
			$ref = $this->dict_node($pubkey);
			# mark an input as having been spent
			$ref->[0]->input_spent($input->prevOutHash,$input->prevOutIndex);
			push(@nodes,$ref->[0]);			
		}
		else{
			return [];
		}
		
	}
	elsif($n == 2){
		warn "I do not know what we have";
		return [];
	}
	else{
		# TODO: check for multisig
		return [];
	}

	
	
	return \@nodes;
}

=pod

---+++ single output

Increases balances and decreases balances.

=cut

sub tx_add_singleoutput{
	my ($this,$input_nodes_ref,$output,$hash,$i) = @_;
	
	#my $script = $output->script;
	
	my $type = CBitcoin::Script::whatTypeOfScript($output->script);
	my @s = split(' ',$output->script);
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
				,'script' => $output->script # scriptPubKey (after being turned into p2sh)
			});
			
			# add output to database
			$node->input_add_p2pkh($t_in,$output->value,$ref->[1],$ref->[2]);			
		}

	}
	elsif($type eq 'return'){
		# have a broadcast!, but don't do anything.....
		if($output->script =~ m/^OP_RETURN\s0x([0-9a-fA-F]+)/){
			my $s = pack('H*',$1);
			foreach my $node (@{$input_nodes_ref}){
				$node->broadcast_receive($s);
			}
		}
	}
	
	return (defined $node) ?  1 : 0;
}

=pod

---++ spend($from_path,@tx_outputs)

=cut

sub spend{
	my ($this,$from_path) = (shift,shift);
	my @outs = @_;

	
	##### figure out the source of funds ######
	my $from_node = $this->node_get_by_path($from_path);
	return undef unless defined $from_node;
	
	
	########## construct change address transaction output #############
	my $total_amount_leaving = 0;
	$total_amount_leaving = [map {$total_amount_leaving +=$_->value} @outs]->[$#outs];
	
	# size of tx
	# for each outpoint, ?
	my ($numOfInputs,$numOfOutputs) = (3,scalar(@outs) + 1); # extra 1 is for change address
	
	my $fee = CBitcoin::Transaction::txfee(4 + 1 + 41*$numOfInputs + 1 + 9*$numOfOutputs + 4);
	
	# find the balance
	my $balance = $from_node->balance();
	
	# need to calculate change address amount
	my $change_amount = $balance - $fee - $total_amount_leaving;
	return undef unless MINTXAMOUNT <= $change_amount;
	my $change_address = $this->deposit($from_path);
	
	# make the change address output
	push(@outs, CBitcoin::TransactionOutput->new({
		'value' => $change_amount
		,'script' => CBitcoin::Script::address_to_script($change_address)
	}));
	
	@outs = shuffle(@outs);
	
	
	
	
	####### construct the transaction inputs ##########
	# find [[$input,$value,$hdkey],...] for outputs
	my $output_ref = $from_node->input_use();
	my @ins;
	my $j = 0;
	my ($N_p2pkh,$N_p2sh) = (scalar(@{$output_ref->{'p2pkh'}}),scalar(@{$output_ref->{'p2sh'}}));
	return undef unless 0 < $N_p2pkh || 0 < $N_p2sh;
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

=pod

---++ cash_move($from,$to,$amount)

Move cash from one node to another node.

=cut

sub cash_move{
	my ($this,$from_path,$to_path,$destination_amount) = @_;
	my $to_node = $this->node_get_by_path($to_path);
	return undef unless defined $to_node;
	return undef unless defined $destination_amount && $destination_amount =~ m/^(\d+)$/;
	$destination_amount = $1;
	my $destination_address = $this->deposit($to_path);
	
	
	my @outs;
	# make the destination address output
	push(@outs, CBitcoin::TransactionOutput->new({
		'value' => $destination_amount
		,'script' => CBitcoin::Script::address_to_script($destination_address)	
	})); 	
	
	
	return $this->spend($from_path,@outs);
}

=pod

---+ Broadcasting

=cut

=pod

---++ broadcast_send($path,$message)->$txdata

For example: $tree->broadcast("ROOT/CHANNEL","BR_SERVER 426655440000123e4567e89b12d3a456123e4567 123e4567-e89b-12d3-a456-426655440000 READMETA|WRITEMETA")

=cut

sub broadcast_send{
	my ($this,$path,$message) = @_;
	
	#### parse the message ######
	
	my $msg = CBitcoin::Tree::Broadcast::serialize($message);
	return undef unless defined $msg;	
	
	#### create and sign transaction ####
	return $this->spend($path,CBitcoin::TransactionOutput->new({
		'value' => 0
		,'script' => "OP_RETURN 0x".unpack('H*',$msg)
	}));
	
}







=pod

---+ db

=cut

=pod

---++ db_tx_lock

=cut

sub db_tx_lock{
	my $this = shift;
	# get a lock on the tx file
	my $fh = $this->{'tx db lock fh'};
	die "no lock" unless defined $fh && 0 < fileno($fh);
	
	my $tries = 0;
	while( !flock($fh, LOCK_EX)  && $tries < 5){
		sleep 1;
		$tries += 1;
	}
	die "cannot lock tx db" if 5 <= $tries;
	
	$this->{'tx db locked'} = 1;
	
}

=pod

---++ db_tx_unlock

=cut

sub db_tx_unlock{
	my $this = shift;
	return undef unless $this->{'tx db locked'};
	
	
	my $fh = $this->{'tx db lock fh'};
	
	flock($fh, LOCK_UN) or die "Cannot unlock tx db - $!\n";
	
	$this->{'tx db locked'} = 0;
}

=pod

---++ db_tx_insert($tx)->0/1

True means successful insert.  False means file already exists.

   1. Write txdata to txh1/txh2/txh3
   1. Create a symlink from tx_3 -> txh1/txh2/txh3 txdata file

=cut

sub db_tx_insert{
	my ($this,$tx,$time_hex) = @_;
	
	my $txbasedir = join('/',$this->base_dir,'..','..','txs');
	
	my $hash = lc(unpack('H*',$tx->hash));
	my @fp;
	if($hash =~ m/^([0-9a-f]{1})([0-9a-f]{2})([0-9a-f]+)$/){
		# db/txs/h1/h2/h3
		@fp = ($txbasedir,$1,$2,$3);
		mkdir(join('/',@fp[0..1]));
		mkdir(join('/',@fp[0..2]));
		
		$hash = $1.$2.$3;
	}
	else{
		die "should not be here with h=$hash";
	}
	
	my $fh;
	if(sysopen ($fh, join('/',@fp), O_RDWR|O_CREAT|O_EXCL, 0600)){
		# file does not exist, so write txdata to disk
		
		binmode($fh);
		
		# get full tx
		my $txdata = $tx->serialize(0);
		my ($m,$n) = (0,length($txdata));
		while(0 < $n - $m){
			$m += syswrite($fh,$txdata,$n - $m, $m);
		}
		close($fh);
	}
	
	return 0 unless defined $time_hex;
	die "bad time" unless $time_hex =~ m/^([0-9a-fA-F]+)$/;
	$time_hex = $1;
	
	# create a symlink from the time directory to the actual txdata file
	# .. we use the time directory to keep track of the ordering of transactions
	# .. we also realize that rename is atomic, but symlink is not.
	# .. therefore, create the symlink at a random location, then move it
	my $tx_fp = join('/',@fp);
	my @link = ($txbasedir,'t_'.$time_hex,$hash);
	mkdir(join('/',@link[0..1]));
	
	my $link_fp = join('/',@link);
	my $init = int(rand(10000));
	if($init =~ m/^(\d+)$/){
		$init = $1;
	}
	
	# create a link (with relative file paths)
	my $curr_dir = Cwd::fastgetcwd();
	# chdir db/txs/t_f4af3abb
	Cwd::chdir(join('/',@link[0..1]));
	# ln -s ../h1/h2/h3  hash
	# h1/h2/h3 = @fp[1..3]
	symlink(join('/','..',@fp[1..3]),$init);
	
	if(rename($init,$hash)){
		Cwd::chdir($curr_dir);
		return 1;
	}
	else{
		unlink($init);
		Cwd::chdir($curr_dir);
		return 0;
	}
}




=pod

---++ db_tx_index()->@txs

Read all new transactions that have been written since the last time this process read the disk.

=cut

sub db_tx_index{
	my ($this) = @_;
	
	#die "no tx" unless defined $tx;
	my @txs;
	
	
	my $fh = $this->{'tx db lock fh'};
	sysseek($fh,0,0);
	my ($n,$buf);
	$n = sysread($fh,$buf,4);
	die "bad lock read" unless $n == 4;
	my $curr_time = unpack('l',$buf);
	my $last_time = $this->{'lock time'};
	
	return @txs unless $last_time < $curr_time;
	
	# db/txs
	my $txbasedir = join('/',$this->base_dir,'..','..','txs');
	
	# read files in alphabetical order
	opendir(my $fhdir,$txbasedir);
	my @files = sort(readdir($fhdir));
	closedir($fhdir);
	# for each file, read the txdata
	my $t = 0;

	foreach my $f (@files){
		next if $f eq '.' || $f eq '..';
		my $name;
		if($f =~ m/^t_([0-9a-fA-F]{8})$/){
			$t = unpack('l',pack('H*',$1));
			$name = 't_'.$1;
			
			next if $t <= $last_time;
		}
		else{
			next;
		}
		
		# read in the txdata
		unless(open(my $fh,'<',$txbasedir.'/'.$name)){
			warn "could not open ".$txbasedir.'/'.$name;
			next;
		}
		
		my ($n,$m,$txdata);
		$n = 0;
		while($m = sysread($fh,$txdata,8192,$n)){
			$n += $m;
		}
		close($fh);
		
		my $tx = CBitcoin::Transaction->deserialize($txdata) || next;
		push(@txs,$tx);
		#$this->tx_add_single(CBitcoin::Transaction->deserialize($txdata));
	}
	
	
	return @txs;
	
}



1;









__END__



