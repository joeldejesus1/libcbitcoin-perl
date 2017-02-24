package CBitcoin::Chain;

use strict;
use warnings;
use BerkeleyDB;
use Math::BigInt only => 'GMP';
use CBitcoin;
use CBitcoin::Chain::Branch;
use CBitcoin::Chain::Node;
use CBitcoin::Utilities;

my $logger = Log::Log4perl->get_logger();

=pod

---+ Chain

=cut


=pod

---+ constructors

=cut

=pod

---++ new({'path' => $fp})

=cut

sub new {
	my ($package) = (shift);
	my $this = {};
	bless($this,$package);
	
	$this->init(@_);
	
	return $this;
}

=pod

---++ init

=cut

sub init{
	my ($this,$options,$block) = @_;
	
	die "no options" unless defined $options && ref($options) eq 'HASH';
	
	$this->{'path'} = CBitcoin::Utilities::validate_filepath($options->{'path'});
	die "no valid path" unless defined $this->{'path'};
	
	
	# DB_CDB_ALLDB means locks apply to all databases (but get invalid arg)
	$this->{'db env'} = new BerkeleyDB::Env(
		-Home => $this->{'path'},
		-Flags  =>	DB_CREATE | DB_INIT_CDB | DB_INIT_MPOOL
	) || die "berkeley env: $BerkeleyDB::Error with error=$!";
	#$logger->debug("DBENV=".$this->{'db env'});
	
	# store chain here
	$this->{'db chain'} = BerkeleyDB::Hash->new(
		-Filename => 'chain.db',
		-Env => $this->{'db env'},
		-Flags  =>	DB_CREATE
	) || die "berkeley database (chain)[path=".$this->{'path'}."/chain.db]: $BerkeleyDB::Error with error=$!";
	#$logger->debug("DBCHAIN=".$this->{'db chain'});
	
	# store data here
	$this->{'db data'} = BerkeleyDB::Hash->new(
		-Filename => 'data.db',
		-Env => $this->{'db env'},
		-Flags  =>	DB_CREATE
	) || die "berkeley database (data)[path=".$this->{'path'}."/data.db]: $BerkeleyDB::Error with error=$!";
	
	#$logger->debug("DBDATA=".$this->{'db data'});
	$this->{'cache'} = {
		'height' => 0
		,'longest branch' => undef
	};
	
	
	$this->init_branches($options);
	
	
}

=pod

---++ init_branches($options)

=cut

sub init_branches {
	my ($this,$options) = @_;
	
	
	my $head_id = $this->get('chain','head');
	if(defined $head_id){
		$logger->debug("Got head=".unpack('H*',$head_id));
		$this->init_branches_fromdb($head_id,$options);
	}
	else{
		$logger->debug("creating new database");
		$this->init_branches_from_genesisblock($options);
	}
	my $branch = $this->branch_longest();
	
	die "Bad Branch Height" if $branch->height == 0;
	
	$this->cache_longest_branch($branch);
	
	
}

=pod

---++ init_branches_fromdb($head_id)

Starting with the node (block) at the end of the longest branch, go back until the genesis block is reached.

=cut

sub init_branches_fromdb {
	my ($this,$head_id,$options) = @_;
	
	
	my $lock = $this->lock();
	my $node = CBitcoin::Chain::Node->load($this,$head_id);
	die "no node was returned, even though it was specified as the head of the chain" unless defined $node;
	$logger->debug("node id=".unpack('H*',$node->id)." and height=".$node->height());
	
	my $branch = CBitcoin::Chain::Branch->new($this,$node);
	$this->branch_add($branch);
	
	$lock->cds_unlock();
	
	# figure out if this is the top of the chain
	$branch->node();
	# after loading the longest branch, double check that we are, in fact, on the longest branch
	$branch = $this->branch_longest();
	
	# just calculate the locator
	my @stuff = $this->block_locator();
	$logger->debug(sub{return "test Locator".join("\n...",@stuff);});
	
}

=pod

---++ init_branches_from_genesisblock($block)

=cut

sub init_branches_from_genesisblock {
	my ($this,$options) = @_;
	
	my $block = $options->{'genesis block'};
	unless(defined $block){
		$block = CBitcoin::Block->genesis_block();
	}
	
	my $node = CBitcoin::Chain::Node->new($block);
	
	my $lock = $this->lock();
	$node->height(1);
	$node->in_chain(1);
	$node->save($this);
	$this->put('chain','head',$node->id);
	$lock->cds_unlock();
	
	my $branch = CBitcoin::Chain::Branch->new($this,$node);
	
	$this->branch_add($branch);
}


=pod

---+ getters/setters

=cut

=pod

---++ db_chain

   * To save a record: <verbatim>{
	my $lk = $chain->db_data->cds_lock();
	my $value;
	$chain->db_data->db_get("Counter", $value);
	$value++;
	$chain->db_data->db_put("Counter", $value);
	
}</verbatim>

=cut

sub db_chain {
	return shift->{'db chain'};
}

=pod

---++ db_data

=cut

sub db_data {
	return shift->{'db data'};
}

=pod

---+ database

=cut

=pod

---++ lock()->$lockobj

Locks the database.

To unlock the database:<verbatim>
my $lock = $chain->lock();
# do stuff...
$lock->cds_unlock();
</verbatim>
   * when $lock goes out of scope, then the lock is released automatically

=cut

sub lock{
	my ($this) = @_;
	return $this->db_data->cds_lock();
}



=pod

---++ put('data',$key,$value)

=cut

sub put{
	my ($this,$name,$key,$value) = @_;
	if($name eq 'data'){
		return $this->db_data->db_put($key,$value);
	}
	elsif($name eq 'chain'){
		return $this->db_chain->db_put($key,$value);
	}
	else{
		die "bad database name";
	}
}

=pod

---++ get('data',$key)

=cut

sub get{
	my ($this,$name,$key) = @_;
	my $value;
	if($name eq 'data'){
		$this->db_data->db_get($key,$value);
		return $value;
	}
	elsif($name eq 'chain'){
		$this->db_chain->db_get($key,$value);
		return $value;
	}
	else{
		die "bad database name";
	}
}


=pod

---++ del('data',$key)

=cut

sub del{
	my ($this,$name,$key) = @_;
	my $value;
	if($name eq 'data'){
		$this->db_data->db_del($key);
		#return $value;
	}
	elsif($name eq 'chain'){
		$this->db_chain->db_del($key);
		#return $value;
	}
	else{
		die "bad database name";
	}
	return 1;
}




=pod

---+ utilities

=cut


=pod

---++ branch_add($branch)

Add a new branch to the chain.

=cut

sub branch_add {
	my ($this,$branch) = @_;
	die "no branch given" unless defined $branch;
	$logger->debug("Got id=".unpack('H*',$branch->id)." height=".$branch->height);
	$this->{'branches'}->{$branch->id} = $branch;

}

=pod

---+ handle blocks

=cut


=pod

---++ branch_update($id,$branch)

While the $branch used to be identified by $id, the $branch->id has changed.  This sub is called in $branch->append($node).

=cut

sub branch_update {
	my ($this,$branch) = @_;
	die "no branch given" unless defined $branch;
	
	delete $this->{'branches'}->{$branch->prev};
	$this->{'branches'}->{$branch->id} = $branch;	
}

=pod

---++ branch_find($id)

Given a $block->prevBlockHash, find the branch we are on.

=cut

sub branch_find {
	my ($this,$id) = @_;
	die "no id" unless defined $id;
	
	if(defined $this->{'branches'}->{$id}){
		return $this->{'branches'}->{$id};
	}
	
	# need to create a new branch based on node
	my $node = CBitcoin::Chain::Node->load($this,$id);
	return undef unless defined $node;
	
	my $branch = CBitcoin::Chain::Branch->new($this,$node);
	$this->branch_add($branch);
	return $branch;
}

=pod

---++ block_append($block)->0/1

Append a block to a branch on this chain.  Returns 0 (false) if the block is an orphan.

=cut

sub block_append {
	my ($this,$block) = @_;
	die "no block" unless defined $block;
	
	
	my $node = CBitcoin::Chain::Node->new($block);
	
	my $othernode = CBitcoin::Chain::Node->load($this,$node->id);
	return 0 if defined $othernode;
	
	my $branch = $this->branch_find($node->prev);
	#return 0 unless defined $branch;
	unless(defined $branch){
#		my $longest_branch = $this->branch_longest();
#		my $latestnode = $longest_branch->node();
#		my $block = CBitcoin::Block->deserialize($latestnode->data.pack('C',0));
		
#		my $timediff = $timestamp - unpack('l',$block->timestamp());
		# check if new block is too old		
		
		$this->block_orphan_add($block);
		return 0;
	}

	#$logger->debug("Appending block=[".unpack('H*',$node->id)."][".unpack('H*',$node->prev)."]\n... to branch=".unpack('H*',$branch->id));
	$branch->append($node);
	
	#if($this->cache_longest_branch->height < $branch->height){
	#	$this->cache_longest_branch($branch);
	#	$logger->debug("appending to longest branch");
		
	# mark the head of the chain
	my $lock = $this->lock();
	$this->put('chain','head',$branch->id());
	$lock->cds_unlock();
	#}
	
	return 1;
}


=pod

---++ block_orphan_add($block)

Store an orphan block.

put(o=$block->hash,$block->header)

=cut

sub block_orphan_add {
	my ($this,$block) = @_;
	
	my $lock = $this->lock();
	my $f = $this->get('data','o='.$block->hash);
	return undef unless defined $f;
	$this->put('data','o='.$block->hash,$block->header);
	
	# as this to list of orphan blocks
	my $list = $this->get('data','blockorphans');
	$list .= $block->hash();
	$this->put('data','blockorphans',$list);
	
	$lock->cds_unlock();
}

=pod

---++ block_orphan_save()

Save orphan blocks that are not orphan any more.  Called in SPV callback_gotheaders.

=cut

sub block_orphan_save {
	my ($this) = @_;
	
	$logger->debug("check to see if the orphan blocks can go on a branch");

	# as this to list of orphan blocks
	my $lock = $this->lock();
	my $list = $this->get('data','blockorphans');
	return undef unless defined $list && 0 < length($list);
	
	$this->del('data','blockorphans');
	$lock->cds_unlock();
	
	my $i = 0;
	while($i * 32 < length($list)){
		my $hash = substr($list,$i*32,32);
		my $data = $this->get('data','o='.$hash);
		next unless defined $data;
		
		
		my $block = CBitcoin::Block->deserialize($data.pack('C',0));
		$this->block_append($block);
		
		$i++;
	}

}


=pod

---++ block_locator($hash_stop)

Given an integer between 1 and the height of the chain, return the block.

=cut

sub block_locator {
	my ($this) = @_;
	#die "no integer" unless defined $i && $i =~ m/(\d+)/ && 0 < $i;
		
	my $branch = $this->branch_longest();
	die "no branches exist" unless defined $branch;
	
	# get every 100k-th block
	return $branch->locator();

	
}

=pod

---++ branch_longest()

Return the longest branch.

=cut

sub branch_longest {
	my ($this) = @_;
	
	return undef unless 0 < scalar(keys %{$this->{'branches'}});
	
	my $lbr;
	my ($score,$height) = (Math::BigInt->new(0),0);
	foreach my $branch_id (keys %{$this->{'branches'}}){
		my $branch = $this->{'branches'}->{$branch_id};
		if($score->bcmp($branch->score) < 0){
			# score < branch
			$lbr = $branch;
			$score = $branch->score->copy();
		}
	}
	
	return $lbr;	
}


=pod

---++ height()

What is the height of the longest branch.

=cut

sub height{
	my ($this) = @_;
	my $branch = $this->branch_longest();
	die "no branch" unless defined $branch;
	return $branch->height();	
}


=pod

---++ cache_longest_branch()

This is used to determine whether or not to save a node as the highest point of the chain.

=cut

sub cache_longest_branch{
	my ($this,$x) = @_;
	if(defined $x && ref($x) eq 'CBitcoin::Chain::Branch'){
		$this->{'cache'}->{'longest branch'} = $x;
	}
	elsif(defined $x){
		die "bad branch";
	}
	return $this->{'cache'}->{'longest branch'};
}




=pod

---++ save()

Return the longest branch.

=cut

sub save{
	my ($this) = @_;
	
	
	my $branch = $this->branch_longest();
	return undef unless defined $branch;
	
	my $head_id = $branch->node->id();
	
	my $lock = $this->lock();
	$this->put('chain','head',$head_id);
	$lock->cds_unlock();
	
}






1;








