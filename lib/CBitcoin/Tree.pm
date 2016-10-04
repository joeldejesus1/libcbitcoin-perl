package CBitcoin::Tree;

use utf8;
use strict;
use warnings;

use CBitcoin::Script;
use Digest::MD5 qw(md5);

use constant {
	MAXACCOUNTS => 1024,

	ROOT => 0
	,CHANNEL => '1|1'
	,CASH => '1/1'
	,SERVERS => '1/2'
	,USERS => '1/3'
};


use Kgc::HTML::Bitcoin::Tree::Node;


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

	$this->{'tree'} = Kgc::HTML::Bitcoin::Tree::Node->new(0);

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
					$nextnode = Kgc::HTML::Bitcoin::Tree::Node->new($x[1]);
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
			warn "generating addresses";
			$this->{'tree'}->max_i_update($this->{'dict'},$this->{'max i'},$i);
			$this->{'max i'} = $i;
		}
		else{
			warn "doing nothing with i=$i";
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

---++ tx_add

=cut

sub tx_add {
	my $this = shift;
	my @done = map {$this->tx_add_single($_)} @_;
	
}

sub tx_add_single {
	my ($this,$tx) = @_;
	die "not a transaction" unless defined $tx && ref($tx) eq 'CBitcoin::Transaction';

	for(my $i=0;$i<$tx->numOfInputs;$i++){
		$this->tx_add_singleinput($tx->input($i));
	}

	for(my $i=0;$i<$tx->numOfOutputs;$i++){
		$this->tx_add_singleoutput($tx->output($i));
	}


	return 1;
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
}

=pod

---+++ single output

Increases balances and decreases balances.

=cut

sub tx_add_singleoutput{
	my ($this,$output) = @_;
	warn "output=$output";
}



1;