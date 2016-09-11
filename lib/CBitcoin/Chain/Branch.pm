package CBitcoin::Chain::Branch;

use utf8;
use strict;
use warnings;



use Math::BigInt only => 'GMP';



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
	$this->{'node'} = $node;
	
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
	return 0 unless $this->node->id eq $node->prev;
	
	
	my $lock = $this->chain->lock();
	
	my $prevnode = $this->node();
	unless(defined $prevnode){
		$lock->unlock();
		die "prev node does not exist";
	}
	
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
	
	$lock->unlock();
	
	$this->chain->branch_update($node->prev,$this);
	
	# this stuff stays in memory
	$this->{'score'} = $node->score()->copy();
	$this->{'height'} = $node->height();
	$this->{'id'} = $node->id();
	$this->{'prev'} = $node->prev;
	
	return 1;
}

=pod

---++ id

=cut

sub id {
	return shift->{'id'};
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

=cut

sub node {
	my ($this) = @_;
	
	# TODO: need to find out if additional blocks have been added
	my $basenode = CBitcoin::Node->load($this->chain,$this->id); 
	
	return $basenode if scalar($basenode->next_all()) == 0;
	
	my $headref = {};
	unless($this->node_x($basenode,$headref)){
		$headref->{$basenode->id} = $basenode;
	}
	
	# TODO: go thru everything....
	
}

sub node_x {
	my ($this,$basenode,$headref) = @_;
	
	my @nextids = $basenode->next_all();
	return 0 unless 0 < scalar(@nextids);
	
	foreach my $next_id (@nextids){
		my $node = CBitcoin::Node->load($this->chain,$next_id);
		# hopefully, catch all loop situations here
		next if $node->height <= $basenode->height;
		unless($this->node_x($node,$headref)){
			$headref->{$node->id} = $node;
		}
		
	}
	
	return 1;
}





1;