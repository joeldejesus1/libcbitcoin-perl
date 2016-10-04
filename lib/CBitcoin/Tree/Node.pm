package CBitcoin::Tree::Node;

use utf8;
use strict;
use warnings;


use CBitcoin::Tree;
use Digest::MD5 qw(md5);



sub new {
	my $package = shift;
	my ($index) = @_;

	die "bad index" unless defined $index && $index =~ m/^(\d+)$/;
	# Kgc::HTML::Bitcoin::Tree::MAXACCOUNTS
	my $this = {
		'prev' => undef
		,'next |' => {}
		,'next /' => {}
		,'index' => $index
		,'hdkey' => undef
		,'hard' => 1
		,'sub index' => Kgc::HTML::Bitcoin::Tree::MAXACCOUNTS
	};
	bless($this,$package);

	return $this;

}

sub index {
	return shift->{'index'};
}

sub hdkey {
	my ($this,$x,$bool) = @_;
	if(defined $x){
		$this->{'hdkey'} = $x;
		return $x if defined $bool && !$bool;
		foreach my $index (keys %{$this->{'next /'}}){
			$this->{'next /'}->{$index}->hdkey($x->deriveChild(1,$index));
		}
		foreach my $index (keys %{$this->{'next |'}}){
			$this->{'next |'}->{$index}->hdkey($x->deriveChild(0,$index));
		}
	}
	elsif(defined $x){
		die "bad hdkey";
	}
	return $this->{'hdkey'};
}

=pod

---++ prev

=cut

sub prev {
	my ($this,$x) = @_;
	if(defined $x && ref($x) eq ref($this)){
		$this->{'prev'} = $x;
	}
	elsif(defined $x){
		die "bad node";
	}
	return $this->{'prev'};
}

=pod

---++ next_add($node,$symbol)

=cut

sub next_add {
	my ($this,$x,$symbol) = @_;
	if(defined $x && ref($x) eq ref($this) && defined $symbol){
		my $nextv = 'next '.$symbol;
		return undef if defined $this->{$nextv}->{$x->index()};
		$this->{$nextv}->{$x->index()} = $x;
	}
	elsif(defined $x){
		die "bad node";
	}
}


=pod

---++ next($index,$symbol)

=cut

sub next {
	my ($this,$index,$symbol) = @_;
	
	return $this->{'next '.$symbol}->{$index};
}

=pod

---++ append($node,$symbol)

=cut

sub append{
	my ($this,$node,$symbol) = @_;

	return undef unless defined $node && ref($node) eq ref($this);
	return undef unless defined $symbol && ( $symbol eq '|' || $symbol eq '/' );

	die "cannot append node because parent is soft xpub" unless $this->hard();

	$node->hard($symbol);
	$this->next_add($node,$symbol);
	$node->prev($this);

}

=pod

---++ sub_index()

Get the current index.  To grab some numbers and increment up, then put in a negative number.

=cut

sub sub_index {
	my $this = shift;
	my $x = shift;
	my $v = 'sub index';
	if(defined $x && $x =~ m/^(\d+)$/){
		$this->{$v} = $1;
		return $this->{$v};
	}
	elsif(defined $x && $x =~ m/^\-(\d+)$/){
		$this->{$v} += $1;	
		return $this->{$v} - $1;
	}
	elsif(defined $x){
		die "bad x";
	}
	else{
		return $this->{$v};
	}
}

=pod

---++ hard('/')

Used when appending nodes to make sure that soft nodes cannot have hard children.

=cut

sub hard{
	my ($this,$symbol) = @_;

	if(defined $symbol && ( $symbol eq '|' || $symbol eq '/' )){
		if($symbol eq '|'){
			$this->{'hard'} = 0;
		}
		elsif($symbol eq '/'){
			$this->{'hard'} = 1;
		}
	}
	elsif(defined $symbol){
		die "bad symbol";
	}

	return $this->{'hard'};
}

=pod

---+ accounting

=cut

=pod

---++ max_i_update($current,$nextmax)

=cut

sub max_i_update {
	my ($this,$dict,$currentmax,$nextmax) = @_;
	die "no dictionary" unless defined $dict && ref($dict) eq 'HASH';

	die "bad max" unless defined $currentmax && $currentmax =~ m/^(\d+)$/ 
		&& defined $nextmax && $nextmax =~ m/^(\d+)$/
		&& $currentmax <= $nextmax && 0 < $currentmax;

	for(my $i=$currentmax;$i<=$nextmax;$i++){
		my ($hash,$p1,$p2);
		my $ref = [$this,$this->hard,$i];
		# store ripemd hash
		$hash = md5($this->hdkey->deriveChild($this->hard,$i)->ripemdHASH160());
		($p1,$p2) = (substr($hash,0,8),substr($hash,8));
		$dict->{$p1}->{$p2} = [] unless defined $dict->{$p1}->{$p2};
		push(@{$dict->{$p1}->{$p2}},$ref);
		# store publickey
		$hash = md5($this->hdkey->deriveChild($this->hard,$i)->publickey());
		($p1,$p2) = (substr($hash,0,8),substr($hash,8));
		$dict->{$p1}->{$p2} = [] unless defined $dict->{$p1}->{$p2};
		push(@{$dict->{$p1}->{$p2}},$ref);
	}
	return $dict;
}







1;