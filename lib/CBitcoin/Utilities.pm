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


sub generate_random {
	my $bytes = shift;
	$bytes ||= 8;
	open(my $fh,'<','/dev/random') || die "cannot open /dev/random";
	my $buf;
	sysread($fh,$buf,$bytes);
	close($fh);
	return $buf;
}


1;