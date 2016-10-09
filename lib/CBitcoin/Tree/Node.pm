package CBitcoin::Tree::Node;

use utf8;
use strict;
use warnings;


use CBitcoin::Tree;
use Digest::MD5 qw(md5);
use Fcntl qw(:flock SEEK_END);


sub new {
	my $package = shift;
	my ($index,$base_dir) = @_;

	die "bad index" unless defined $index && $index =~ m/^(\d+)$/;
	# Kgc::HTML::Bitcoin::Tree::MAXACCOUNTS
	my $this = {
		'prev' => undef
		,'next |' => {}
		,'next /' => {}
		,'index' => $index
		,'hdkey' => undef
		,'hard' => 1
		,'sub index' => CBitcoin::Tree::MAXACCOUNTS
		,'output pool' => {}
		,'output pool unique check' => {}
		,'output inflight' => {}
		,'output spent' => {}
		,'callbacks' => []
		,'base directory' => $base_dir
	};
	bless($this,$package);

	return $this;

}

=pod

---++ balance($type)

Get the balance for the current node.  Default is output pool.

For satoshi outbound but not confirmed yet, set type='inflight'.

=cut

sub balance {
	my ($this,$type) = @_;
	# go thru all the outputs:  [$type,$input,$value,...]
	my $sum = 0;
	my $href;
	if(!defined $type){
		$href = $this->{'output pool'};
	}
	elsif($type eq 'inflight'){
		# how many satoshi have been spent, but not confirmed
		$href = $this->{'output inflight'};
	}
	else{
		die "bad type";
	}
	
	foreach my $k (keys %{$href}){
		$sum += $href->{$k}->[2];
	}
	
	return $sum;	
	
}

=pod

---++ balance_recursive($type)

Get the balance for this node and all child nodes.

=cut

sub balance_recursive {
	my ($this,$type) = @_;
	my $sum = 0;
	
	foreach my $sym ('|','/'){
		my $hardbool = ($sym eq '|') ? 1 : 0;
		foreach my $i (keys %{$this->{'next '.$sym}}){
			$sum += $this->{'next '.$sym}->{$i}->balance_recursive($type);
		}
	}
	
	$sum += $this->balance($type);
	
	return $sum;
}

=pod

---++ input_add_p2pkh($txinput,$value,$hardbool,$index)

Add an input that can be used in a future transaction.

=cut

sub input_add_p2pkh {
	my ($this,$input,$value,$hardbool,$index) = @_;
	#warn "input_add_p2pkh:[".unpack('H*',$input->prevOutHash)."][".$input->prevOutIndex."]\n";
	$this->{'output pool'}->{$input->prevOutHash.$input->prevOutIndex} = ['p2pkh',$input,$value,$hardbool,$index]; 
}

=pod

---++ input_use()

Use all inputs in node.  If type=p2pkh, then the ref=['p2pkh',$input,$value,$hardbool,$index].

Returns:<verbatim>{
	'p2pkh' => [[$input,$value,$hdkey],...]
	,'p2sh' => [[$input,$value,$m,$hdkey1,$hdkey2,....],...]
}

=cut

sub input_use{
	my ($this) = @_;
	
	# create file on disk, and lock it
	
	
	my $out = {'p2pkh' => [], 'p2sh' => []};
	foreach my $y (keys %{$this->{'output pool'}}){
		my $ref = $this->{'output pool'}->{$y};
		# db/trees/wallet/../../inputs_inflight
		my $input_fp = join('/',
			$this->base_dir
			,'..','..'
			,'inputs_inflight'
			,unpack('H*',$ref->[1]->prevOutHash).$ref->[1]->prevOutIndex
		);
		
		if(mkdir($input_fp)){
			# another process is already using this
			$this->{'output inflight'}->{$ref->[1]->prevOutHash.$ref->[1]->prevOutIndex} = $ref;
			#push(@{$this->{'output inflight'}},$ref);
			if($ref->[0] eq 'p2pkh'){
			#	warn "input_use:[".unpack('H*',$ref->[1]->prevOutHash)."][".$ref->[1]->prevOutIndex."]\n";
				push(@{$out->{'p2pkh'}},[$ref->[1],$ref->[2],$this->hdkey->deriveChild($ref->[3],$ref->[4])]);	
			}
			elsif($ref->[0] eq 'p2sh'){
				die "cannot do multisig yet";
			}
			delete $this->{'output pool'}->{$y};
		}
		else{
			warn "input is being used already with I=$input_fp";	
		}
		

	}
	
	return $out;
}

=pod

---++ input_spent($prevHash,$prevIndex)

Mark an input as having been spent.

=cut

sub input_spent {
	my ($this,$prevHash,$prevIndex) = @_;
	#warn "input_spent:[".unpack('H*',$prevHash)."][".$prevIndex."]\n";
	# TODO: dont use a loop to find the input, use a %hash next time
	
	if(defined $this->{'output inflight'}->{$prevHash.$prevIndex}){
		warn "moving input from inflight to spent";
		$this->{'output spent'}->{$prevHash.$prevIndex} = $this->{'output inflight'}->{$prevHash.$prevIndex};
		delete $this->{'output inflight'}->{$prevHash.$prevIndex};
	}
	elsif(defined $this->{'output pool'}->{$prevHash.$prevIndex}){
		warn "moving input from pool to spent";
		$this->{'output spent'}->{$prevHash.$prevIndex} = $this->{'output pool'}->{$prevHash.$prevIndex};
		delete $this->{'output pool'}->{$prevHash.$prevIndex};		
	}
	else{
	#	warn "what happened?";
	}
	
	my $input_fp = join('/',
		$this->base_dir
		,'..','..'
		,'inputs_inflight'
		,unpack('H*',$prevHash).$prevIndex
	);
	# the directory MUST be empty before removing it
	rmdir($input_fp);
	
}

=pod

---++ base_dir

=cut

sub base_dir {
	return shift->{'base directory'};
}

=pod

---++ index

=cut

sub index {
	return shift->{'index'};
}

=pod

---++ hdkey($cbhd,$bool)


=cut

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
	#warn "updating from $currentmax to $nextmax";
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
	
	
	foreach my $sym ('|','/'){
		my $hardbool = ($sym eq '|') ? 1 : 0;
		foreach my $i (keys %{$this->{'next '.$sym}}){
			my $node = $this->{'next '.$sym}->{$i};
			$node->max_i_update($dict,$currentmax,$nextmax);
		}
	}
	
	
	return $dict;
}

=pod

---+ Broadcasting

=cut

=pod

---++ broadcast_receive($node,$serialized_message)->$txdata


=cut

sub broadcast_receive{
	my ($this,$message) = @_;
	die "no message!" unless defined $message;
	$message = CBitcoin::Tree::Broadcast::deserialize($message);
	return undef unless defined $message;
	
	my $n = scalar(@{$this->{'callbacks'}});
	return undef unless 0 < $n;
	for(my $i=0;$i<$n;$i++){
		$this->{'callbacks'}->[$i]->($this,$message);
	}
	
}

=pod

---++ broadcast_callback($sub)->return_id

=cut

sub broadcast_callback{
	my ($this,$sub) = @_;
	return undef unless defined $sub;
	die "bad sub" unless ref($sub) eq 'CODE';
	
	push(@{$this->{'callbacks'}},$sub);
	
	return scalar(@{$this->{'callbacks'}}) - 1;
}








1;










__END__