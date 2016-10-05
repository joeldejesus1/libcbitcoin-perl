package CBitcoin::Utilities;

use strict;
use warnings;

use Net::IP;
use Net::DNS;
use CBitcoin;
use Convert::Base32;
use constant TORPREFIX => 'fd87d87eeb43';

use Log::Log4perl;
my $logger = Log::Log4perl->get_logger();

=pod


---+ Utility Subroutines


=cut

=pod

---++ fisher_yates_shuffle($array_ref)

Shuffle an array in place.

=cut

sub fisher_yates_shuffle
{
    my $array = shift;
    my $i = @$array;
    while ( --$i )
    {
        my $j = int rand( $i+1 );
        @$array[$i,$j] = @$array[$j,$i];
    }
}

=pod

---++ ip_convert_to_binary($string)

Convert AAA.BBB.CCC.DDD to network byte notation, an onion address to ipv6 local address, or an ipv6.

=cut

sub ip_convert_to_binary {
	
	my($string) = (shift);
	
	if($string =~ m/^([0-9A-Za-z]+)\.onion$/){
		# return a tor address
		return pack('H*',TORPREFIX).Convert::Base32::decode_base32($1);
	}
	
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

Untaint here and figure out if we are dealing with an ipv4, ipv6, or onion address.

=cut

sub ip_convert_to_string {
	my $binipv6 = shift;
	
	my $stripv6 = unpack('H*',$binipv6);
	
	# untaint
	if($stripv6 =~ m/^([0-9a-fA-F]+)$/){
		$stripv6 = $1;
	}
	else{
		die "we should not be here.";
	}
	if($stripv6 eq '00000000000000000000ffff00000000'){
		return '00000000000000000000ffff00000000';
	}
	elsif(substr($stripv6,0,24) eq '00000000000000000000ffff'){
		#warn "ipv4 with full=$stripv6\n";
		return hex2ip(substr($stripv6,24,8));
	}
	# FD87:D87E:EB43 is the official tor prefix for local ipv6 addresses
	elsif(substr($stripv6,0,12) eq TORPREFIX){
		# return an onion address
		return Convert::Base32::encode_base32(pack('H*',substr($stripv6,12))).'.onion';
	}
	elsif($stripv6 =~ m/^([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})$/){
		#warn "ipv6\n";
		return "$1:$2:$3:$4:$5:$6:$7:$8";
	}
	else{
		die "bad address format";
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
	
	my $ans;
	$ans->{'services'} = substr($data,0,8);
	# TODO: find a better way to untaint a binary value
	if(unpack('H*',$ans->{'services'}) =~ m/^(.*)$/){
		$ans->{'services'} = pack('H*',$1);
	}
	
	$ans->{'ipaddress'} = ip_convert_to_string(substr($data,8,16));
	
	$ans->{'port'} = unpack('n',substr($data,24,2));
	
	if($ans->{'port'} =~ m/^(\d+)$/){
		$ans->{'port'} = $1;
	}
	else{
		die "port did not untaint";
	}

	return $ans;
}

=pod

---++ network_address_deserialize($file_handle)

Get timestamp, services, ipaddress, port.

=cut

sub network_address_deserialize {
	my $fh = shift;
	my $ans = {};
	my ($n, $buf);
	$n = read($fh,$buf,4);
	$ans->{'timestamp'} = unpack('L',$buf);
	die "bad addr network addr" unless $n == 4;
	my $diff = time() - $ans->{'timestamp'};
	unless(abs($diff) < 8*60*60){
		#warn "bad addr, might be stale\n";
		$n = read($fh,$buf,30-4);
		die "bad addr packet" unless $n == 26;
		return undef
	}
	#warn "Timestamp diff=$diff\n";

	$n = read($fh,$buf,8);
	die "no network addr services" unless $n == 8;
	$ans->{'services'} = $buf;

	
	$n = read($fh,$buf,16);
	die "no network addr ipaddress" unless $n == 16;
	$ans->{'ipaddress'} = ip_convert_to_string($buf);
	unless(defined $ans->{'ipaddress'}){
		#warn "ip address format is bad\n";
		#die "bad addr"
		$n = read($fh,$buf,30-4-8-16);
		
		# make sure that this does not connect to local host!!!!!
		
		return undef;
	}
	#warn "ip address of peer is ip=".$ans->{'ipaddress'}."\n";
	
	
	$n = read($fh,$buf,2);
	die "no network addr port" unless $n == 2;
	$ans->{'port'} = unpack('n',$buf);
	unless( $ans->{'port'} ){
		#warn "ip address format is bad\n";
		#die "bad addr"
		return undef;
	}
	#warn "port of peer is port=".$ans->{'port'}."\n";
	
	
	# TODO: find a better way to untaint a binary value
	if(unpack('H*',$ans->{'services'}) =~ m/^(.*)$/){
		$ans->{'services'} = pack('H*',$1);
	}
	# ipaddress has already been untainted
	# untaint the port number
	if($ans->{'port'} =~ m/^(\d+)$/){
		$ans->{'port'} = $1;
	}
	else{
		die "port did not untaint";
	}
	return $ans;
}


sub generate_random {
	my $bytes = shift;
	$bytes ||= 8;
	open(my $fh,'<','/dev/random') || die "cannot open /dev/random";
	my ($n,$buf) = (0,undef);
	while(0 < $bytes - $n){
		$n += sysread($fh,$buf,$bytes-$n,$n); 
	}
	close($fh);
	$logger->debug("$bytes vs ".length($buf));
	return $buf;
}


sub generate_urandom {
	my $bytes = shift;
	$bytes ||= 8;
	open(my $fh,'<','/dev/urandom') || die "cannot open /dev/urandom";

	my ($n,$buf) = (0,undef);
	while(0 < $bytes - $n){
		$n += sysread($fh,$buf,$bytes-$n,$n); 
	}
	close($fh);
	$logger->debug("$bytes vs ".length($buf));
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

=pod

---++ deserialize_inv($fh)->[$type,$hash]

Deserialize inventory vectors.

=cut

sub deserialize_inv{
	my $fh = shift;
	my ($n,$buf);
	$n = read($fh,$buf,4);
	die "not enough bytes to read type" unless $n == 4;
	my $type = unpack('L',$buf);
	
	$n = read($fh,$buf,32);
	die "not enough bytes to read hash" unless $n == 32;
	
	return [$type,$buf];
}

=pod

---++ serialize_varint($integer)

=cut

sub serialize_varint {
	my $integer = shift;
	die "bad integer" unless defined $integer && $integer =~ m/^(\d+)$/;
#	$logger->debug("Got integer=$integer");
	if($integer < 0xfd ){
#		$logger->debug("outputting:".unpack('H*',pack('C',$integer)));
		return pack('C',$integer);
	}
	elsif($integer <= 0xffff){
		return pack('C',0xfd).pack('S',$integer);
	}
	elsif($integer <= 0xffffffff){
		return pack('C',0xfe).pack('L',$integer);
	}
	else{
		return pack('C',0xff).pack('Q',$integer);
	}
}

=pod

---++ serialize_varstr($string)
   * [[https://github.com/bitcoin/bips/blob/master/bip-0014.mediawiki][bip-0014]]
IE: /Satoshi:5.64/bitcoin-qt:0.4/


=cut

sub serialize_varstr {
	my $str = shift;
	$str = '' unless defined $str;
	$logger->debug("length=".length($str)." for string=$str");
	return serialize_varint(length($str)).$str;
}

=pod

---++ deserialize_addr($file_handle)

=cut

sub deserialize_addr{
	my $fh = shift;
	my $count = -1;
	$count = deserialize_varint($fh);
	if(defined $count && 0 < $count){
		my @addrs;
		while($count){
			$count = $count -1;
			# what about null addresses? 00000000000000000000ffff00000000
			my $newaddr = network_address_deserialize($fh);
			push(@addrs, $newaddr) if defined $newaddr && $newaddr->{'ipaddress'} ne '00000000000000000000ffff00000000';
			
			#warn "adding address to pool\n";
		}
		return \@addrs;
	}
	else{
		#warn "bad peer, b/c bad addr packet\n";
		# TODO: kill connection
		return undef;
	}
}


=pod

---++ serialize_getheaders(\@blocklocator,$hashstop)

=cut

sub serialize_getheaders {
	my ($version,$blocklocatorref,$hashstop) = (shift,shift,shift);
	
	unless(defined $blocklocatorref && ref($blocklocatorref) eq 'ARRAY' && scalar(@{$blocklocatorref}) > 0){
		#warn "not enough block locators\n";
		return undef;
	}
	unless(length(join('',@{$blocklocatorref})) == 32 * scalar(@{$blocklocatorref})){
		#warn "length mismatch\n";
		return undef;
	}
	if(defined $hashstop && length($hashstop) == 32){
		#warn "hashstop checks out\n";
	}
	elsif(!defined $hashstop){
		#warn "null hashstop\n";
		$hashstop = pack('x');
		foreach my $i (2..32){
			$hashstop .= pack('x');
		}
	}
	
	return pack('L',$version).serialize_varint(scalar(@{$blocklocatorref})).join('',@{$blocklocatorref}).$hashstop;
}


=pod

---++ serialize_addr($network_addr1,$network_addr2,...)

=cut

sub serialize_addr{
	my $buffer = '';
	my $i = 0;
	foreach my $addr  (@_){
		die "bad address" unless defined $addr && ref($addr) eq 'ARRAY' && scalar(@{$addr}) == 4;
		$buffer .= network_address_serialize(@{$addr});
		$i++;
	}
	die "no addresses to send" unless 0 < $i;
	return serialize_varint($i).$buffer;
}

=pod

---++ HashToFilepath

1,3,the rest

=cut

sub HashToFilepath {
	my $x = shift;
	return (substr($x,0,1),substr($x,1,3),substr($x,4));
}

=pod

---++ FilepathToHash

=cut

sub FilepathToHash {
	my $path  = shift;
	$path =~ s/\///g;
	return $path;
}

=pod

---++ recursive_mkdir($path)

=cut

sub recursive_mkdir {
    my $path = shift;
    
    my @parts = split /\//, $path;
    for my $num (1..$#parts) {
        my $check = join('/', @parts[0..$num]);
        unless (-d $check) {
            mkdir( $check );
        }
    }
}

=pod

---++ block_locator_indicies($top_depth)->@indexes

To create the block locator hashes, keep pushing hashes until you go back to the genesis block.  After pushing 10 hashes back, the step backwards doubles every loop.

For $top_depth, put the currently confirmed block height.

=cut

sub block_locator_indicies{
	my $top_depth = shift;
	$top_depth = 10 unless defined $top_depth && $top_depth =~ m/^\d+$/ && 0 <= $top_depth;
	
	my @ans;
	
	my ($step,$start,$i) = (1,0,$top_depth);
	
	while($i > 1){
		if(10 <= $start ){
			$step *= 2; 
		}
		push(@ans,$i);
		$i -= $step;
		$start += 1;
	}
	push(@ans,1);
	return @ans;
}


=pod

---++ validate_filepath($file_path,$prefix)

Strip the prefix and run a regex to validate the file path

A full path must always be provided.

=cut

sub validate_filepath {
	my $fp = shift;
	my $prefix = shift;
	$prefix = '' unless defined $prefix;
	return undef unless defined $fp && 0 < length($fp);
	
	my $prefix_check = substr($fp,0,length($prefix));
	return undef unless $prefix_check eq $prefix;
	
	$fp = substr($fp,length($prefix));
	
	my $leading_slash = 0;
	my @untainted;
	foreach my $dir (split('/',$fp)){
		if($dir eq '' && !$leading_slash){
			$leading_slash = 1;
			push(@untainted,'');
			next;
		}
		elsif($dir eq ''){
			return undef;
		}
		
		
		if($dir =~ m/^([^*&%\s]+)$/){
			push(@untainted,$1);
		}
		else{
			return undef;
		}
	}
	return join('/',@untainted);
}


=pod

---++ dns_fetch_peers()

Fetch peers via DNS requests, returns serialized addr packets.

=cut

our $node_seeds;
BEGIN{
	$node_seeds = [time(),[]];
}

sub dns_fetch_peers{
	my $dest = shift;
	
	return $node_seeds->[1] if time() - $node_seeds->[0] < 5*60*60  && 0 < scalar(@{$node_seeds->[1]});
	
	my $port;
	$dest = undef unless defined $dest && ref($dest) eq 'ARRAY' && 0 < scalar(@{$dest});
	if($CBitcoin::network_bytes == CBitcoin::MAINNET){
		$port  = 8333;
		$dest //= [
			"seed.breadwallet.com", "seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "dnsseed.bitcoin.dashjr.org",
			"seed.bitcoinstats.com", "bitseed.xf2.org", "seed.bitcoin.jonasschnelli.ch"
		];
	}
	elsif($CBitcoin::network_bytes == CBitcoin::TESTNET){
		$port = 18333;
		$dest //= [
			"test.seed.breadwallet.com"
		];
	}
	else{
		die "bad network bytes";
	}
	
	my $res   = Net::DNS::Resolver->new;
	
	my @addresses;
	foreach my $host (@{$dest}){
		# A for ipv4 and AAAA for ipv6
		foreach my $type ('A','AAAA'){
			my $reply = $res->query($host,$type);
			if ($reply) {
				foreach my $rr ($reply->answer) {
					#print $rr->address, "\n";
					push(@addresses,[time(),pack('Q',1),$rr->address,$port]);
				}
			} else {
				$logger->debug("query failed: ".$res->errorstring);
			}
		}
		
	}
	$node_seeds->[1] = \@addresses;
	
	
	
	
	$node_seeds->[0] = time();
	
	return $node_seeds->[1];
}













1;