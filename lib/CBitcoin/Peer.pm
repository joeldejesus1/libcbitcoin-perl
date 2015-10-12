package CBitcoin::Peer;

use strict;
use warnings;
use CBitcoin::Message; # out of laziness, all c functions get referenced out of CBitcoin::Message
use CBitcoin::Utilities;
use constant BUFFSIZE => 8192;



sub new {
	my $package = shift;
	
	my $options = shift;
	die "no options given" unless defined $options && ref($options) eq 'HASH' && defined $options->{'address'} && defined $options->{'port'} 
		&& defined $options->{'our address'} && defined $options->{'our port'} && defined $options->{'socket'} && fileno($options->{'socket'}) > 0;
		
	$options->{'block height'} ||= 0;
	$options->{'version'} ||= 70002; 
	$options->{'magic'} = 'MAINNET' unless defined $options->{'magic'};
	
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
		'handshake finished' => 0,'sent version' => 0, 'sent verack' => 0, 'received version' => 0, 'received verack' => 0,
		'buffer'=> {},
		'socket' => $options->{'socket'},
		'message definition' => {'magic' => 4,'command' => 12, 'length' => 4, 'checksum' => 4 },
		'message definition order' => ['magic','command', 'length', 'checksum','payload' ]
	};
	# to have some human readable stuff for later 
	$this->{'address'} = $options->{'address'};
	$this->{'port'} = $options->{'port'};
	
	bless($this,$package);
	$this->{'handshake'}->{'our version'} = $this->version_serialize(
		$options->{'address'},$options->{'port'},
		$options->{'our address'},$options->{'our port'},
		time(),$options->{'version'},$options->{'block height'}
	); 
	$this->send_version();
	

	
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this);
	#warn "XO=$xo\n";
	
	return $this;
}


=pod

---+ Getters/Setters

=cut

sub handshake_finished{
	return shift->{'handshake finished'};
}

sub sent_version {
	return shift->{'sent version'};
}
sub sent_verack {
	return shift->{'sent verack'};
}
sub received_version {
	return shift->{'received version'};
}
sub received_verack {
	return shift->{'received verack'};
}

sub address {
	return shift->{'address'};
}

sub port {
	return shift->{'port'};
}
sub magic {
	return shift->{'magic'};
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
	#warn "Version=".unpack('H*',$x);
	$data .= $x;
	# services, 0
	$x = pack('Q',$services);
	#warn "services=".unpack('H*',$x);
	$data .= $x;
	# timestamp
	$x = pack('q',$lastseen);
	#warn "timestamp=".unpack('H*',$x);
	$data .= $x;
	# addr_recv
	$x =  CBitcoin::Utilities::network_address_serialize_forversion($services,$addr_recv_ip,$addr_recv_port);
	#warn "addr_recv=".unpack('H*',$x);
	$data .= $x;
	# addr_from
	$x = CBitcoin::Utilities::network_address_serialize_forversion($services,$addr_from_ip,$addr_from_port);
	#warn "addr_from=".unpack('H*',$x);
	$data .= $x;
	# nonce
	$x = CBitcoin::Utilities::generate_random(8);
	#warn "nonce=".unpack('H*',$x);
	$data .= $x;
	# user agent (null, no string)
	$x = pack('C',0);
	#warn "user agent=".unpack('H*',$x);
	$data .= $x;
	# start height
	$x = pack('l',$blockheight);
	#warn "blockheight=".unpack('H*',$x);
	$data .= $x;
	# bool for relaying
	$x = pack('C',0);
	#warn "bool for relaying=".unpack('H*',$x);
	$data .= $x;
	return $data;
}

sub send_version {
	my $this = shift;
	$this->{'sent version'} = 1;
	return $this->write(CBitcoin::Message::serialize($this->our_version(),'version'));
}

sub send_verack {
	my $this = shift;
	$this->{'sent verack'} = 1;
	return $this->write(CBitcoin::Message::serialize('','verack',$this->magic));
}




=pod

---+ Callbacks


sub sent_version {
	return shift->{'sent version'};
}
sub sent_verack {
	return shift->{'sent verack'};
}
sub received_version {
	return shift->{'received version'};
}
sub received_verack {
	return shift->{'received verack'};
}

=cut


=pod

---++ callback_gotversion


=cut

sub callback_gotversion {
	my $this = shift;
	
	
	# handshake should not be finished
	if($this->handshake_finished()){
		die "bad peer";
	}
	
	# we should not already have a version
	if($this->received_version()){
		die "peer already sent a version";
	}
	
	# parse version
	#open(my)
	
	
	$this->send_verack();
	
}




=pod

---++ callback_gotverack


=cut

sub callback_gotverack {
	my $this = shift;
	
	die "hand shake getverack";
	
	# should we be getting a verack
}





=pod

---+ Read/Write

=cut

sub read_data {
	my $this = shift;
	
	$this->{'bytes'} = '' unless defined $this->{'bytes'};
	
	# read in magic
	$this->bytes_read(sysread($this->socket(),$this->{'bytes'},8192,length($this->{'bytes'})));
	warn "Read in ".$this->bytes_read()." bytes\n";
	foreach my $key (@{$this->{'message definition order'}}){
		#warn "reading in data for $key\n";
		return 0 unless $this->read_data_alpha($key);
	}
	# have a message
	#foreach my $key (@{$this->{'message definition order'}}){
	#	warn "$key => [".unpack('H*',$this->{'buffer'}->{$key})."]\n";	
	#}
	my $msg = CBitcoin::Message->new($this->{'buffer'});
	
	if($msg->command eq 'version'){
		$this->callback_gotversion($msg);
		return undef;
	}
	elsif($msg->command eq 'verack'){
		$this->callback_gotverack($msg);
		return undef;
	}
	elsif($this->handshake_finished()){
		return $msg;
	}
	else{
		die "bad client behavior";
	}
	
}



sub read_data_alpha {
	my $this = shift;
	my ($key) = (shift);
	
	my $size = $this->definition_size_mapper($key);
	die "key not defined" unless defined $size;
	
	
	if(!defined $this->{'buffer'}->{$key} &&  $this->{'bytes read'} >= $size){
		$this->{'buffer'}->{$key} = substr($this->{'bytes'},0,$size);
		#warn "Pre $key=".unpack('H*',$this->{'buffer'}->{$key})."\n";
		substr($this->{'bytes'},0,$size) = ""; # delete  bytes we don't need
		$this->{'bytes read'} = $this->{'bytes read'} - $size;
		die "sizes do not match" unless $this->{'bytes read'} == length($this->{'bytes'});
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
		die "length not defined" unless defined $this->{'buffer'}->{'length'};
		return unpack('L',$this->{'buffer'}->{'length'});
	}
	else{
		return $this->{'message definition'}->{$key};
	}
}

=pod

---++ write($data)

Add to the write queue.

=cut

sub write {
	my $this = shift;
	my $data = shift;
	return undef unless defined $data && length($data) > 0;
	$this->{'bytes to write'} .= $data;
	
}

=pod

---++ write_data()

When we can write data, send out 8192 bytes.

=cut

sub write_data {
	my $this = shift;
	return undef unless defined $this->{'bytes to write'} && length($this->{'bytes to write'}) > 0;
	
	my $n = syswrite($this->socket(),$this->{'bytes to write'},8192);
	substr($this->{'bytes to write'},0,$n) = "";
	return $n;
}

1;