package CBitcoin::Chain::Node;

use strict;
use warnings;

use Math::BigInt only => 'GMP';

use CBitcoin::Chain::Branch;
use CBitcoin::Chain::Node;
use CBitcoin::Utilities;

my $logger = Log::Log4perl->get_logger();

=pod

---+ Node

=cut

our $min_diff;

BEGIN{
	$min_diff = Math::BigInt->from_hex('00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');
}


=pod

---+ constructors

=cut

=pod

---++ new($block)

=cut

sub new {
	my ($package) = (shift);
	my $this = {};
	bless($this,$package);
	
	$this->init(@_);
	
	return $this;
}

=pod

---++ init() 

=cut

sub init {
	
	my ($this,$block) = @_;
	
	
	$this->{'id'} = $block->hash();
	$this->{'data'} = $block->header();
	$this->{'height'} = 0;
	$this->{'score'} = $min_diff->copy()->bsub($block->hash_bigint());
	$this->{'prev'} = $block->prevBlockHash();
	$this->{'next ids'} = [] unless defined $this->{'next ids'};
	
	
	$this->in_chain(0);
}



=pod

---+ getters/setters

=cut

=pod

---++ in_chain -> 0/1

Is this in the chain or not?

=cut

sub in_chain {
	my ($this,$x) = @_;
	
	if($x){
		$this->{'is inserted in chain?'} = 1;
	}
	elsif(defined $x){
		$this->{'is inserted in chain?'} = 0;
	}
	return $this->{'is inserted in chain?'};
}

=pod

---++ id

=cut

sub id {
	return shift->{'id'};
}

=pod

---++ data

=cut

sub data {
	return shift->{'data'};
}

=pod

---++ prev($id)

=cut

sub prev {
	my ($this,$x) = @_;
	
	if(defined $x){
		$this->{'prev'} = $x;
	}
	return $this->{'prev'};
}

=pod

---++ next_add($id)

=cut

sub next_add {
	my ($this,$x) = @_;
	if(defined $x && !defined $this->{'next ids proof'}->{$x}){
		$logger->debug("already added");
	}
	elsif(defined $x){
		$this->{'next ids proof'} = 1;
		push(@{$this->{'next ids'}},$x);
		
	}
	else{
		die "no id specified";
	}
}


=pod

---++ next_all()->@

=cut

sub next_all {
	my ($this) = @_;
	
	return @{$this->{'next ids'}};
}

=pod

---++ score

This is BigInt.  If in_chain is false, then the score is only the hash bigint from the block, not the cummulative difficulty.

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

---+ utilities

=cut

=pod

---++ save($chain)

Format of node: [prev, 32B][height, 4B][length of score, 1B][score, ?B][num of next, 1B][..nextid,32B]

This will lock the database long enough for the changes to be saved to disk.

=cut

sub save{
	my ($this,$chain) = @_;
	
	die "cannot save node" unless $this->in_chain();
	
	my $score = pack('H*',$this->score()->as_hex());

	my $lk = $chain->lock();
	
	
	my $numOfNext = scalar(@{$this->{'next ids'}});
	my $nexts = pack('C',$numOfNext);
	if($numOfNext){
		$nexts = $nexts.join('',sort @{$this->{'next ids'}});
	}
	
	$logger->debug("saving node: id=[".unpack('H*',$this->id)."] ");
	
	$chain->put('chain',
		$this->id
		,$this->prev
			.pack('L',$this->height)
			.pack('C',length($score)).$score
			.$nexts
	);
	
	$chain->put('data',
		$this->id
		,$this->data
	);
}


=pod

---++ load($chain,$id)

Load the block header and branch information from the database.

=cut

sub load{
	my ($package,$chain,$id) = @_;
	my $this = {};
	bless($this,$package);
	
	# this is the 80B block header without the tx count
	$this->{'data'} = $chain->get('data',$id);
	return undef unless defined $this->{'data'};
	
	$this->{'id'} = $id;
	
	
	# this contains the node prev/next link information along with the score
	my $chain_data = $chain->get('chain',$id);
	return undef unless defined $chain_data && 0 < length($chain_data);
	
	open(my $fh,'<',\$chain_data);
	my ($n,$buf);
	
	# get the prev id
	$n = read($fh,$buf,32);
	return undef unless $n == 32;
	$this->{'prev'} = $buf;
	
	# get the height
	$n = read($fh,$buf,4);
	return undef unless $n == 4;
	$this->{'height'} = unpack('L',$buf);	
	
	# get the score
	$n = read($fh,$buf,1);
	return undef unless $n == 1;
	my $len = unpack('C',$buf);
	
	$n = read($fh,$buf,$len);
	return undef unless $n == $len;
	$this->{'score'} = Math::BigInt->from_hex(unpack('H*',$buf));
	
	
	# get the next ids
	
	$n = read($fh,$buf,1);
	return undef unless $n == 1;
	$len = unpack('C',$buf);	
	
	$this->{'next ids'} = [];
	for(my $i=0;$i<$len;$i++){
		$n = read($fh,$buf,32);
		return undef unless $n == 32;
		push(@{$this->{'next ids'}},$buf);
	}
	
	$this->in_chain(1);
	
	return $this;
}









1;