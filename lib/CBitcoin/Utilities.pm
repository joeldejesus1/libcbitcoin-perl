package CBitcoin::Utilities;

use strict;
use warnings;
use Net::IP;


=pod


---+ Utility Subroutines


=cut


=pod

---++ ip_convert_to_binary($string)

Convert AAA.BBB.CCC.DDD to network byte notation

=cut

sub ip_convert_to_binary {
	my($string) = (shift);
	my $ip  = Net::IP->new($string);
	if(length(unpack('H*',pack('B*',$ip->binip())) ) < 12){
		# set it so it goes in as an ipv6, cuz bitcoin mandates
		return pack('H*','00000000000000000000ffff'.unpack('H*',pack('B*',$ip->binip())));
	}
	else{
		return pack('H*',unpack('H*',pack('B*',$ip->binip())));
	}	
}


=pod

---++ ip_convert_to_string

=cut

sub ip_convert_to_string {
	my $binipv6 = shift;
	
	my $stripv6 = unpack('H*',$binipv6);
	
	if(substr($stripv6,0,24) eq '00000000000000000000ffff'){
		warn "ipv4 with full=$stripv6\n";
		return hex2ip(substr($stripv6,24,8));
	}
	else{
		warn "ipv6\n";
		return $stripv6;
	}
}

# helper function
sub hex2ip { return join(".", map {hex($_)} unpack('A2 A2 A2 A2',shift)) }




sub network_address_serialize {
	my ($time,$services,$ipaddr,$port) = @_;
	my $data = pack('L',$time);
	$data .= pack('Q',$services);
	$data .= ip_convert_to_binary($ipaddr);
	$data .= pack('n',$port);
	return $data;
}

sub network_address_serialize_forversion {
	my ($services,$ipaddr,$port) = @_;
	my $data = '';
	$data .= pack('Q',$services);
	$data .= ip_convert_to_binary($ipaddr);
	$data .= pack('n',$port);
	return $data;
}

sub network_address_deserialize_forversion {
	my $data = shift;
	die "bad data with length=".length($data) unless length($data) == 26;
	return {
		'services' => substr($data,0,8),
		'ipaddress' => ip_convert_to_string(substr($data,8,16)),
		'port' => unpack('n',substr($data,24,2))
	};
}



sub generate_random {
	my $bytes = shift;
	$bytes ||= 8;
	open(my $fh,'<','/dev/random') || die "cannot open /dev/random";
	my $buf;
	sysread($fh,$buf,$bytes);
	close($fh);
	return $buf;
}

=pod

---++ deserialize_varstr($file_handle)

=cut
sub deserialize_varstr {
	my $fh = shift;
	my ($buf,$n);
	# length
	my $length = deserialize_varint($fh);
	$n = read($fh,$buf,$length);
	die "bad varstr, too short" unless $n == $length;
	return $buf;
}

=pod

---++ deserialize_varint($fh)

=cut

sub deserialize_varint {
	my $fh = shift;
	my ($n,$buf,$total,$prefix);

	$n = read($fh,$buf,1);
	die "varint too short" unless $n == 1;
	$prefix = unpack('C',$buf);
	if($prefix < 0xfd){
		return $prefix;
	}
	elsif($prefix == 0xfd ){
		$n = read($fh,$buf,2);
		die "varint too short for uint16_t" unless $n == 2;
		return unpack('S',$buf);
	}
	elsif($prefix == 0xfe ){
		$n = read($fh,$buf,4);
		die "varint too short for uint32_t" unless $n == 4;
		return unpack('L',$buf);
	}
	elsif($prefix == 0xff ){
		$n = read($fh,$buf,8);
		die "varint too short for uint64_t" unless $n == 8;
		return unpack('Q',$buf);
	}
	else{
		die "we should not be here, logically";
	}
	
}


1;