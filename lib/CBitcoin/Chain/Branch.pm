package CBitcoin::Chain::Branch;

use utf8;
use strict;
use warnings;

use Math::BigInt only => 'GMP';

use CBitcoin::Chain::Node;
use CBitcoin::Utilities;

my $logger = Log::Log4perl->get_logger();





=pod

---+ Branch

=cut

=pod

---+ constructors

=cut


=pod

---++ new($chain,$node)

=cut

sub new{
	my ($package) = (shift);
	
	my $this = {};
	bless($this,$package);
	
	$this->{'block queue'} = [];
	
	$this->init(@_);
	
	
	
	return $this;
}

=pod

---++ init

=cut

sub init{
	my ($this,$chain,$node) = @_;
	
	die "no chain" unless defined $chain;
	die "no node" unless defined $node;
	
	$this->{'chain'} = $chain;
	
	$this->{'score'} = $node->score()->copy();
	$this->{'height'} = $node->height();
	$this->{'id'} = $node->id();
	$this->{'prev'} = $node->prev;
	
	die "no id" unless defined $this->{'id'};
	
	
	
}

=pod

---+ utilities

=cut


=pod

---++ append($node)->0/1

Do a lock here and add the node to the end of this branch.  Returns 0 if the node does not belong on this branch.

=cut

sub append{
	my ($this,$node) = @_;
	die "node is already in chain" if $node->in_chain();
	# make sure that this is the correct branch 
	#$logger->debug("1");
	
	my $lock = $this->chain->lock();
	my $prevnode = $this->node();
		
	
	unless(defined $prevnode){
		$lock->cds_unlock();
		die "prev node does not exist";
	}	
	
	die "ids dont match" unless $prevnode->id eq $node->prev;
	#$logger->debug(" ids match ");

	
	# update prevnode
	$prevnode->next_add($node->id);
	# update node
	$node->prev($prevnode->id);
	# update the score
	$node->score(
		$prevnode->score->copy->badd($node->score)
	);
	# update the height
	$node->height($prevnode->height() + 1);
	
	# appending complete, mark the node as in the chain
	$node->in_chain(1);
	
	# node and prevnode will be deleted from memory, but stored in the database
	$prevnode->save($this->chain);
	$node->save($this->chain);
	
	# save reference blockheight -> block->hash.
	$this->node_queue_save();
	
	$lock->cds_unlock();
	
	$this->node_queue_add($node);
	
	# this stuff stays in memory
	$this->{'score'} = $node->score()->copy();
	$this->{'height'} = $node->height();
	$this->{'id'} = $node->id();
	$this->{'prev'} = $node->prev;

	# delete the old link to this branch, and put in a new link with the correct $node->id
	$this->chain->branch_update($this);
	
	return 1;
}

=pod

---++ id

=cut

sub id {
	return shift->{'id'};
}

=pod

---++ prev

=cut

sub prev {
	return shift->{'prev'};
}

=pod

---++ score

This is BigInt.

=cut

sub score {
	return shift->{'score'};
}

=pod

---++ height

=cut

sub height {
	return shift->{'height'};
}

=pod

---++ chain

=cut

sub chain {
	return shift->{'chain'};
}

=pod

---++ node()

Always load the node from the database, in case any changes have taken place.

If there have been any changes to the database, find the heighest node out of the new branches created.

=cut

sub node {
	my ($this) = @_;
	
	# TODO: need to find out if additional blocks have been added
	my $basenode = CBitcoin::Chain::Node->load($this->chain,$this->id); 
	
	return $basenode if scalar($basenode->next_all()) == 0;
	
	# lock the db so that we dont end up in an infinite loop
	my $lock = $this->chain->lock();
	
	my $headref = {};
	# go thru all the new nodes, find the head nodes at the end of their respective branches
	unless($this->node_recursive($basenode,$headref)){
		$headref->{$basenode->id} = $basenode;
	}
	# everything is in memory now, so release the lock
	$lock->cds_unlock();
	
	my ($lbr,$returnnode);
	my ($bool,$height,$score) = (0,0, Math::BigInt->new(0));
	foreach my $head_id (keys %{$headref}){
		my $tmpbranch;
		# create new branches and/or update this branch to point to the end of the chain
		if(!$bool){
			# just update this branch
			$this->init($this->chain,$headref->{$head_id});
			$bool = 1;
			$tmpbranch = $this;
		}
		else{
			# create a new branch
			$tmpbranch = CBitcoin::Chain::Branch->new($this->chain,$headref->{$head_id});
			$this->chain->branch_add($tmpbranch);
		}
		
		# this section is for figuring out the longest branch, thereby which new node to return
		if($score->bcmp($tmpbranch->score) < 0){
			# score < branch
			$lbr = $tmpbranch;
			$score = $tmpbranch->score->copy();
			$returnnode = $headref->{$head_id};
		}
		
	}
	
	# return node that has the highest score
	return $returnnode;
}

=pod

---+++ node_recursive($basenode,$headref)

From a single node, go up each branch until you get the head nodes on multiple branches.  Then put references to those nodes in the $headref.

$headref maps $node->id to $node.

=cut

sub node_recursive {
	my ($this,$basenode,$headref) = @_;
	
	my @nextids = $basenode->next_all();
	return 0 unless 0 < scalar(@nextids);
	
	my $bool = 0;
	foreach my $next_id (@nextids){
		my $node = CBitcoin::Chain::Node->load($this->chain,$next_id);
		# hopefully, catch all loop situations here
		next if $node->height <= $basenode->height;
		unless($this->node_recursive($node,$headref)){
			$headref->{$node->id} = $node;
		}
		
		$bool = 1;
	}
	
	return $bool;
}


=pod

---++ locator()->$arrayref

=cut

sub locator{
	my ($this) = @_;

	my @blocks;

	
	my $node = $this->node();
	my $branch_height = $node->height();
	die "Branch height is 0" unless 0 < $branch_height;
	#$logger->debug("height=$branch_height");
	my @indicies = CBitcoin::Utilities::block_locator_indicies($branch_height);
	
	# check to see if we have a link to the db via block height
	
	
	my $index = shift(@indicies);
	
	$logger->debug(sub{
		require Data::Dumper;
		return "indicies:".Data::Dumper::Dumper(\@indicies);
	});
	
	
	$logger->debug("Branch=".$this."  height=".$node->height());
	while(1 < $node->height() && 0 < scalar(@indicies)){
		my $oldheight = $node->height();
		#$logger->debug("current height=$oldheight: index=$index");
		
		
		if($oldheight == $index){
			#$logger->debug("Adding node to locator: index=$index");
			$index = shift(@indicies);
			push(@blocks,$node->id());
			
			# see if we can skip down to the next needed block
			my $prevnode_id = $this->chain->get('chain','i='.$index);
			if(defined $prevnode_id){
				$node = CBitcoin::Chain::Node->load($this->chain,$prevnode_id);
				die "bad chain, need to fix" unless defined $node && $node->height == $index;
				next;
			}
			
		}
		
		# iterate to the previous node		
		$node = CBitcoin::Chain::Node->load($this->chain,$node->prev);
		die "bad chain, need to fix" unless defined $node;
		die "bad node, need to fix" unless $node->height() == $oldheight -1;

	}
	# this should be the genesis block
	push(@blocks,$node->id());
	
	
	
	return \@blocks;
}


=pod

---++ node_queue_add($node)

Add blocks to queue.

=cut

sub node_queue_add{
	my ($this,$node) = @_;
	die "no node" unless defined $node;
	
	#$logger->debug("Ref=".ref(\@x));
	push(@{$this->{'block queue'}},[$node->height,$node->id]);
}

=pod

---++ node_queue_save()

Once the blocks are comfortably behind the head of the branch (ie secure), save a reference to them via block height.

=cut

sub node_queue_save {
	my ($this) = @_;

	my $branch_height = $this->height();
	
	
	
	my ($i,$n) = (0,scalar(@{$this->{'block queue'}}));
	
	while($i < $n){
		my $xref = shift(@{$this->{'block queue'}});
		
		#$logger->debug("Xref=".ref($xref)." hi=".$xref);
		#die "not an array ref" unless ref($xref) eq 'HASH';
		$i++;
		if(20 < $branch_height - $xref->[0]){
			$this->chain->put('chain','i='.$xref->[0],$xref->[1]);
		}
		else{
			push(@{$this->{'block queue'}},$xref);
		}
	}
}


1;