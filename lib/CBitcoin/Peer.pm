package CBitcoin::Peer;

use strict;
use warnings;
use CBitcoin::Message; # out of laziness, all c functions get referenced out of CBitcoin::Message
use CBitcoin::Utilities;


sub new {
	my $package = shift;
	
	my $options = shift;
	die "no options given" unless defined $options && ref($options) eq 'HASH' && defined $options->{'address'} && defined $options->{'port'} 
		&& defined $options->{'our address'} && defined $options->{'our port'};
		
	$options->{'block height'} ||= 0;
	$options->{'version'} ||= 70002; 
	
	
	die "no good ip address given" unless CBitcoin::Utilities::ip_convert_to_binary($options->{'address'})
		&& CBitcoin::Utilities::ip_convert_to_binary($options->{'our address'});
	
	die "no good ports given" unless $options->{'port'} =~ m/^\d+$/ && $options->{'our port'} =~ m/^\d+$/;
	

	#createversion1(addr_recv_ip,addr_recv_port,addr_from_ip,addr_from_port,lastseen,version,blockheight)
#	my $this = CBitcoin::Message::createversion1(
#		CBitcoin::Utilities::ip_convert_to_binary($options->{'address'}),$options->{'port'}
#		,CBitcoin::Utilities::ip_convert_to_binary($options->{'our address'}), $options->{'our port'}
#		,pack('q',time()) # last seen
#		,$options->{'version'} # version
#		,$options->{'block height'} # block ehight
#	);
	my $this = {
		'buffer'=> {},
		'message definition' => {'magic' => 4,'command' => 12, 'length' => 4, 'checksum' => 4 }
	};
	bless($this,$package);
	$this->{'handshake'}->{'our version'} = $this->version_serialize(
		$options->{'address'},$options->{'port'},
		$options->{'our address'},$options->{'our port'},
		time(),$options->{'version'},$options->{'block height'}
	); 
	
	
	# to have some human readable stuff for later 
	$this->{'address'} = $options->{'address'};
	$this->{'port'} = $options->{'port'};
	
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this);
	#warn "XO=$xo\n";
	
	return $this;
}


=pod

---+ Getters/Setters

=cut

sub address {
	return shift->{'address'};
}

sub port {
	return shift->{'port'};
}


sub our_version {
	return shift->{'handshake'}->{'our version'};
}

sub socket {
	return shift->{'socket'};
}

sub bytes_read{
	my $this = shift;
	my $newbytes = shift;
	if(defined $newbytes ){
		$this->{'bytes read'} += $newbytes;  #implies undefined means 0
		return $this->{'bytes read'};
	}
	elsif(!defined $newbytes){
		return $this->{'bytes read'};
	}
	else{
		die "number of bytes in bad format";
	}
}

sub bytes {
	my $this = shift;
	my $newbytes = shift;
	if(defined $newbytes && length($newbytes) > 0){
		$this->{'bytes'} .= $newbytes; 
		return $this->{'bytes'};
	}
	else{
		return $this->{'bytes'};
	}
}

=pod

---+ Handshakes

=cut

sub version_serialize {
	my $this = shift;
	my ($addr_recv_ip,$addr_recv_port,$addr_from_ip,$addr_from_port,$lastseen,$version,$blockheight) = @_;
	
	my $services = 0;
	
	my $data = '';
	my $x = '';
	# version 
	$x = pack('l',$version);
	warn "Version=".unpack('H*',$x);
	$data .= $x;
	# services, 0
	$x = pack('Q',$services);
	warn "services=".unpack('H*',$x);
	$data .= $x;
	# timestamp
	$x = pack('q',$lastseen);
	warn "timestamp=".unpack('H*',$x);
	$data .= $x;
	# addr_recv
	$x =  CBitcoin::Utilities::network_address_serialize_forversion($services,$addr_recv_ip,$addr_recv_port);
	warn "addr_recv=".unpack('H*',$x);
	$data .= $x;
	# addr_from
	$x = CBitcoin::Utilities::network_address_serialize_forversion($services,$addr_from_ip,$addr_from_port);
	warn "addr_from=".unpack('H*',$x);
	$data .= $x;
	# nonce
	$x = CBitcoin::Utilities::generate_random(8);
	warn "nonce=".unpack('H*',$x);
	$data .= $x;
	# user agent (null, no string)
	$x = pack('C',0);
	warn "user agent=".unpack('H*',$x);
	$data .= $x;
	# start height
	$x = pack('l',$blockheight);
	warn "blockheight=".unpack('H*',$x);
	$data .= $x;
	# bool for relaying
	$x = pack('C',0);
	warn "bool for relaying=".unpack('H*',$x);
	$data .= $x;
	return $data;
}

=pod

---+ Read/Write

=cut

sub read_data {
	my $this = shift;
	my $fh = $this->socket();
	$this->{'bytes read'} = 0 unless defined $this->
	my $buf,$n;
	# read in magic
	$this->bytes_read(sysread($fh,$this->{'bytes'},8192,length($this->{'bytes'})));
	warn "Read in ".$this->bytes_read()." bytes\n";
	foreach my $key (keys %{$this->{'message definition'}},'payload size'){
		return 0 unless $this->read_data_alphah($key);
	}
	return 1;
}

sub read_data_alpha {
	my $this = shift;
	my ($key) = (shift);
	
	my $size = $this->definition_size_mapper($key);
	die "key not defined" unless defined $size;
	
	
	if(!defined $this->{'buffer'}->{$key} &&  $this->{'bytes read'} >= $size){
		$this->{'buffer'}->{$key} = substr($this->{'bytes'},0,$size);
		substr($this->{'bytes'},0,$size) = ''; # delete  bytes we don't need
		$this->{'bytes read'} = $this->{'bytes read'} - $size;
		return 1;
	}
	else{
		return 0;
	}
}

sub definition_size_mapper {
	my $this = shift;
	my $key = shift;
	if($key eq 'payload'){
		return $this->{'payload size'};
	}
	else{
		return $this->{'message definition'}->{$key};
	}
}


1;