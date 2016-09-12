package CBitcoin::Chain;

use strict;
use warnings;
use BerkeleyDB;



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
	
	
	# DB_CDB_ALLDB means locks apply to all databases
	$this->{'db env'} = new BerkeleyDB::Env(
		-Home => $this->{'path'},
		-Flags  =>	DB_CREATE | DB_INIT_CDB | DB_INIT_MPOOL | DB_CDB_ALLDB
	) || die "cannot open environment: $BerkeleyDB::Error\n";
	# store chain here
	$this->{'db chain'} = new BerkeleyDB::Env(
		-Filename => 'chain.db',
		-CacheSize => 10*1024*1024,
		-Env => $this->{'db env'}
	) || die "cannot open database: $BerkeleyDB::Error\n";
	# store data here
	$this->{'db data'} = new BerkeleyDB::Env(
		-Filename => 'data.db',
		-CacheSize => 5*1024*1024,
		-Env => $this->{'db env'}
	) || die "cannot open database: $BerkeleyDB::Error\n";	
	
	
	$this->init_branches($options);
}

=pod

---++ init_branches($options)

=cut

sub init_branches {
	my ($this,$options) = @_;
	
	my $head_id = $this->get('chain','head');
	if(defined $head_id){
		$this->init_branches_fromdb($head_id,$options);
	}
	else{
		$this->init_branches_from_genesisblock($options);
	}
}

=pod

---++ init_branches_fromdb($head_id)

Starting with the node (block) at the end of the longest branch, go back until the genesis block is reached.

=cut

sub init_branches_fromdb {
	my ($this,$head_id,$options) = @_;
	
	my $lock = $this->lock();
	my $node = CBitcoin::Chain::Node->load($this->chain,$id);
	die "no node was returned, even though it was specified as the head of the chain" unless defined $node;
	$this->branch_add(
		CBitcoin::Chain::Branch->new($this->chain,$node)
	);
	
	$lock->unlock();
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
	$node->save($this);
	$this->put('chain','head',$node->id);
	$lock->unlock();
	
	my $branch = CBitcoin::Branch->new($this,$node);
	
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
$lock->unlock();
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
	my ($this,$name) = (shift,shift);
	if($name eq 'data'){
		return $this->db_data->db_put(shift,shift);
	}
	elsif($name eq 'chain'){
		return $this->db_chain->db_put(shift,shift);
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
		return $this->db_data->db_get($key,$value);
	}
	elsif($name eq 'chain'){
		return $this->db_chain->db_get($key,$value);
	}
	else{
		die "bad database name";
	}
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
	
	$this->{'branches'}->{$branch->id} = $branch;
}

=pod

---++ branch_update($id,$branch)

While the $branch used to be identified by $id, the $branch->id has changed.  This sub is called in $branch->append($node).

=cut

sub branch_update {
	my ($this,$id,$branch) = @_;
	die "no id" unless defined $id;
	die "no branch given" unless defined $branch;
	
	delete $this->{'branches'}->{$id};
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
	my $node = CBitcoin::Chain::Node->load($chain,$id);
	return undef unless defined $node;
	
	my $branch = CBitcoin::Chain::Branch->new($node);
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
	
	my $branch = $this->branch_find($node->prev);
	return 0 unless defined $branch;
	
	$branch->append($node);
	
	return 1;
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
	foreach my $branch (keys %{$this->{'branches'}}){
		if($score->bcmp($branch->score) < 0){
			# score < branch
			$lbr = $branch;
			$score = $branch->score->copy();
		}
	}
	
	return $lbr;	
}


=pod

---++ save()

Return the longest branch.

=cut

sub save{
	my ($this) = @_;
	
	
	my $branch = $this->branch_longest();
	return undef unless defined $branch;
	
	my $headid = $branch->node->id();
	
	my $lock = $this->lock();
	$this->put('chain','head',$head_id);
	$lock->unlock();
	
}






1;








