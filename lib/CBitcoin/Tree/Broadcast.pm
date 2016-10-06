package CBitcoin::Tree::Broadcast;

use utf8;
use strict;
use warnings;

use constant {
	BR_SERVER => 1
	,BR_USER => 2

	, S_READMETA => 1
	, S_WRITEMETA => 2
	, S_READINDEX => 4
	, S_READCIPHER => 8
	, S_READPLAIN => 16
};




our $constants;


BEGIN{
	$constants->{'to'}->{'BR'} = {
		'BR_SERVER' => BR_SERVER
		,'BR_USER' => BR_USER
	};
	
	# for BR_SERVER
	$constants->{'to'}->{'S'} = {
		'READMETA' => S_READMETA
		,'WRITEMETA' => S_WRITEMETA
		,'READINDEX' => S_READINDEX
		,'READCIPHER' => S_READCIPHER
		,'READPLAIN' => S_READPLAIN
	};
	
	foreach my $t ('BR','S'){
		foreach my $k (keys %{$constants->{'to'}->{$t}}){
			$constants->{'from'}->{$t}->{$constants->{'to'}->{$t}->{$k}} = $k;
		}
	}
}



=pod

---++ serialize($string)

Examples:
   * BR_UUIDSET $uuid $path

=cut

our $mapper;

sub serialize{
	my ($string) = @_;
	return undef unless defined $string && 0 < length($string);
	
	my @s = split(/\s+/,$string);
	my $x = shift(@s);
	if(defined $x && defined $mapper->{'serialize'}->{$x}){
		return $mapper->{'serialize'}->{$x}->(@s);
	}
	else{
		warn "cannot parse string"; 
		return undef;
	}
	
}

=pod

---++ deserialize($binary_from_OP_RETURN)

=cut

sub deserialize{
	my ($message) = @_;

	return undef unless defined $message && 0 < length($message);
	my $ref = $mapper->{'deserialize'};
	
	open(my $fh,'<',\$message);
	binmode($fh);
	
	my $buf = _fhread($fh,1);
	return undef unless defined $buf;
	$buf = unpack('C',$buf);

	$buf = $constants->{'from'}->{'BR'}->{$buf};
	if(defined $buf && defined $ref->{$buf}){
		return $ref->{$buf}->($fh);
	}
	else{
		return undef;
	}
}

=pod

---++ USER

Format: USER [$ripemd, 20B] [$uuid, 16B] [$RightsBitField, 2B]

Always big endian.

=cut

BEGIN{
		$mapper->{'serialize'}->{'BR_USER'} = \&serialize_userset;
}

sub serialize_userset {
	my @args = @_;
	return undef unless scalar(@args) == 3;

	my $data = pack('C',BR_USER);


	# check ripemd
	if($args[0] =~ m/^([0-9a-fA-F]{40})$/){
		$data .= pack('H*',$1);
	}
	else{
		return undef;
	}

	# check uuid
	if($args[1] =~ m/^([0-9a-fA-F]{32})$/){
		$data .= pack('H*',$1);
	}
	elsif($args[1] =~ m/^([0-9a-fA-F]{8})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{12})$/){
		$data .= pack('H*',$1.$2.$3.$4.$5);
	}
	else{
		return undef;
	}
	
	# rights bit field
	my $y = serialize_userrights($args[2]);
	return undef unless defined $y;
	$data .= $y;
	
	return $data;
}



=pod

---+++ User Rights

Format: READMETA|WRITEMETA

=cut

sub serialize_userrights {
	my $string = shift;
	return undef unless defined $string && 0 < length($string);
	my $data = 0;
	my $ref =$constants->{'to'}->{'S'};
	foreach my $r (split('|',$string)){
		my $s = $ref->{$r};
		return undef unless defined $s;
		$data |= $s;
	}
	
	return pack('S',$data);
}

sub deserialize_userrights {
	die "not done";
}

=pod

---++ SERVER

Format: BR_SERVER [$ripemd, 20B] [$uuid, 16B] [$RightsBitField, 2B]

Rights:
   * READMETA
   * WRITEMETA
   * READINDEX
   * READCIPHER
   * READPLAIN


=cut

BEGIN{
	$mapper->{'deserialize'}->{'BR_SERVER'} = \&deserialize_serverset;
	$mapper->{'serialize'}->{'BR_SERVER'} = \&serialize_serverset;
}


sub deserialize_serverset {
	my $fh = shift;
	my ($n,$buf);

	my @ans = 'BR_SERVER';
	
	# ripemd 160b hash
	$buf = _fhread($fh,20);
	return undef unless defined $buf;
	push(@ans,unpack('H*',$buf));
	
	# uuid
	$buf = _fhread($fh,16);
	return undef unless defined $buf;	
	push(@ans,unpack('H*',$buf));
	
	# rights bit field
	$buf = _fhread($fh,2);
	return undef unless defined $buf;
	$buf = deserialize_serverrights($buf);
	return undef unless defined $buf;
	push(@ans,$buf);
	
	return join(' ',@ans);
}




sub serialize_serverset {
	my @args = @_;
	return undef unless scalar(@args) == 3;

	my $data = pack('C',BR_SERVER);


	# check ripemd
	if($args[0] =~ m/^([0-9a-fA-F]{40})$/){
		$data .= pack('H*',$1);
	}
	else{
		return undef;
	}
	# check uuid
	if($args[1] =~ m/^([0-9a-fA-F]{32})$/){
		$data .= pack('H*',$1);
	}
	elsif($args[1] =~ m/^([0-9a-fA-F]{8})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{12})$/){
		$data .= pack('H*',$1.$2.$3.$4.$5);
	}
	else{
		return undef;
	}
	
	# rights bit field
	my $y = serialize_serverrights($args[2]);
	return undef unless defined $y;
	$data .= $y;
	return $data;
}


=pod

---+++ Server Rights

Format: READMETA|WRITEMETA

=cut

sub serialize_serverrights {
	my $string = shift;
	return undef unless defined $string && 0 < length($string);
	my $data = 0;
	my $ref = $constants->{'to'}->{'S'};
	foreach my $r (split(/\|/,$string)){
		my $s = $ref->{$r};
		return undef unless defined $s;
		$data |= $s;
	}
	
	return pack('S',$data);
}

sub deserialize_serverrights {
	my $number = shift;
	return undef unless defined $number && length($number) == 2;
	$number = unpack('S',$number);
	
	my @ans;
	foreach my $x (keys %{$constants->{'from'}->{'S'}}){
		if($number & $x){
			push(@ans,$constants->{'from'}->{'S'}->{$x});
		}
	}
	return undef unless 0 < scalar(@ans);
	
	return join('|',@ans);
}




























sub _fhread{
	my ($fh,$m) = @_;
	my $buf;
	return undef unless read($fh,$buf,$m) == $m;
	return $buf;
}







1;