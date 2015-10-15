package CBitcoin::Peer;

use strict;
use warnings;
use CBitcoin::Message; # out of laziness, all c functions get referenced out of CBitcoin::Message
use CBitcoin::Utilities;
use constant BUFFSIZE => 8192;

our $callback_mapper;


=pod

--++ new($options)

   * Required: 'address', 'port', 'socket', 'our address', 'our port'
      * 'socket' must be an already open socket
   * Optional: 'block height', 'version', 'magic'

=cut

sub new {
	my $package = shift;
	
	my $options = shift;
	die "no options given" unless defined $options && ref($options) eq 'HASH' && defined $options->{'address'} && defined $options->{'port'} 
		&& defined $options->{'our address'} && defined $options->{'our port'} && defined $options->{'socket'} && fileno($options->{'socket'}) > 0;
	
	die "need spv base" unless defined $options->{'spv'};
	
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
		'spv' => $options->{'spv'},
		'socket' => $options->{'socket'},
		'message definition' => {'magic' => 4,'command' => 12, 'length' => 4, 'checksum' => 4 },
		'message definition order' => ['magic','command', 'length', 'checksum','payload' ],
		'command buffer' => {}
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

---++ finish

Call this subroutine to disconnect and delete this peer.

=cut

sub finish {
	my $this = shift;
	$this->spv->close_peer(fileno($this->socket()));
	return 1;
}

=pod

---++ is_marked_finished

Has this peer been mark finished?

=cut

sub is_marked_finished {
	return shift->{'is marked finished'};
}

=pod

---++ mark_finished

Do this to passively terminate peer.

=cut

sub mark_finished {
	shift->{'is marked finished'} = 1;
}


=pod

---+ Getters/Setters

=cut

sub handshake_finished{
	my $this = shift;
	
	if($this->{'handshake finished'}){
		warn "handhsake is finished\n";
		return 1;
	}
	
	if($this->sent_version && $this->sent_verack && $this->received_version && $this->received_verack){
		$this->{'handshake finished'} = 1;
		warn "handshake is finished\n";
		return 1;
	}
	else{
		return 0;
	}
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

sub spv {
	return shift->{'spv'};
}

sub block_height {
	my $this = shift;
	my $new_height = shift;
	if(defined $new_height && $new_height =~ m/^(\d+)$/){
		$this->{'block height'} += $1;
		return $this->{'block height'};
	}
	elsif(!defined $new_height){
		return $this->{'block height'};
	}
	else{
		die "bad block height";
	}
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

sub last_pinged {
	return shift->{'last pinged'};
}

sub command_buffer {
	return shift->{'commands'}->{shift};
}


sub bytes_read{
	my $this = shift;
	my $newbytes = shift;
	if(defined $newbytes && $newbytes > 0){
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

sub version_deserialize {
	my $this = shift;
	my $msg = shift;
	open(my $fh,'<',\$msg->{'payload'}) || die "cannot read versio payload";
	my $version = {};
	my @ver_order = ('version','services','timestamp','addr_recv','addr_from','nonce','user_agent','block_height','relay');
	my $vers_size = {
		'version' => 4, 'services' => 8, 'timestamp' => 8, 'addr_recv' => 26, 'addr_from' => 26,
		'nonce' => 8,'user_agent' => -2, 'block_height' => 4, 'relay' => 1
	};
	my ($n,$buf);
	foreach my $key (@ver_order){
		my $size = $vers_size->{$key};
		
		if($size == -2){
			# need to read var_str
			$version->{$key} = CBitcoin::Utilities::deserialize_varstr($fh);
			warn "Reading var string with result=".$version->{$key}."\n";
			next;
		}
		
		$n = read($fh,$buf,$vers_size->{$key});
		$version->{$key} = $buf;
		warn "For $key, got n=$n and value=".unpack('H*',$buf)."\n";
		
		unless($n == $vers_size->{$key}){
			warn "bad bytes, size does not match";
			return undef;
		}
		
	}
	
	# version, should be in this range
	unless(70000 < unpack('l',$version->{'version'}) && unpack('l',$version->{'version'}) < 80000 ){
		warn "peer supplied bad version number\n";
		return undef;
	}
	# services
	if($version->{'services'} & pack('Q',1)){
		warn "NODE_NETWORK \n";
	}
	else{
		warn "Just provides headers\n";
	}
	# timestamp, should not be more than 5 minutes old
	my $timediff = time () - unpack('q',$version->{'timestamp'});
	if(abs($timediff) < 1*60 ){
		warn "peer time is within error bound, diff=$timediff seconds\n";
	}
	else{
		warn "peer time is too far off, diff=$timediff seconds\n";
	}
	# addr_recv
	$version->{'addr_recv'} = CBitcoin::Utilities::network_address_deserialize_forversion($version->{'addr_recv'});
	# addr_from
	$version->{'addr_from'} = CBitcoin::Utilities::network_address_deserialize_forversion($version->{'addr_from'});
	# nonce
	# make sure we don't have another peer with the same nonce?
	
	# blockheight (do sanity check)
	$version->{'block_height'} = unpack('l',$version->{'block_height'});
	unless(0 <= $version->{'block_height'}){
		warn "bad block height of ".$version->{'block_height'}."\n";
		return undef;
	}
	$this->block_height($version->{'block_height'});
	
	# bool for relaying, should we relay
	warn "Relay=".unpack('C',$version->{'relay'})."\n";
	close($fh);
	
	$this->{'version'} = $version;
	
	
	
	return $this->{'version'};
}


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

sub send_ping {
	my $this = shift;
	warn "Sending ping\n";
	$this->{'sent ping nonce'} = CBitcoin::Utilities::generate_random(8);
	
	return $this->write(CBitcoin::Message::serialize($this->{'sent ping nonce'},'ping',$this->magic));
}

sub send_pong {
	my $this = shift;
	my $nonce = shift;
	die "bad nonce" unless defined $nonce && length($nonce) == 8;
	warn "Sending pong\n";
	return $this->write(CBitcoin::Message::serialize($nonce,'pong',$this->magic));
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

---++ callback_gotaddr


=cut

BEGIN{
	$callback_mapper->{'command'}->{'addr'} = {
		'subroutine' => \&callback_gotaddr
	}
};

sub callback_gotaddr {
	my $this = shift;
	my $msg = shift;
	
	open(my $fh,'<',\$msg->{'payload'});
	my $addr_ref = CBitcoin::Utilities::deserialize_addr($fh);
	close($fh);
	
	if(defined $addr_ref && ref($addr_ref) eq 'ARRAY'){
		warn "Got ".scalar(@{$addr_ref})." new addresses\n";
		
		foreach my $addr (@{$addr_ref}){
			# timestamp, services, ipaddress, port
			$this->spv->add_peer_to_db(
				$addr->{'services'},
				$addr->{'ipaddress'},
				$addr->{'port'}
			);
		}
	}
	else{
		warn "Got no new addresses\n";
	}
	return 1;
	
}


=pod

---++ callback_gotversion


=cut

sub callback_gotversion {
	my $this = shift;
	my $msg = shift;
	
	# handshake should not be finished
	if($this->handshake_finished()){
		warn "peer already finished handshake, but received another version\n";
		$this->mark_finished();
		return undef;
	}
	
	# we should not already have a version
	if($this->received_version()){
		warn "peer already sent a version\n";
		$this->mark_finished();
		return undef;
	}


	# parse version	
	unless($this->version_deserialize($msg)){
		warn "peer sent bad version\n";
		$this->mark_finished();
		return undef;
	}
	
	
	#open(my)
	$this->{'received version'} = 1;
	
	$this->send_verack();
	return 1;
}


=pod

---++ callback_gotverack


=cut

sub callback_gotverack {
	my $this = shift;
	
	
	# we should not have already received a verack
	if($this->received_verack()){
		warn "bad peer, already received verack";
		$this->mark_finished();
		return undef;
	}
	
	# we should have sent a version
	if(!$this->sent_version()){
		warn "no version sent, so we should not be getting a verack\n";
		$this->mark_finished();
		return undef;
	}
	
	$this->{'received verack'} = 1;
	
	$this->send_ping();
	return 1;
}

=pod

---++ callback_ping

=cut

sub callback_gotping {
	my $this = shift;
	my $msg = shift;
	warn "Got ping\n";
	unless($this->handshake_finished()){
		warn "got ping before handshek finsihed\n";
		$this->mark_finished();
		return undef;
	}
	$this->send_pong($msg->payload());
	return 1;
}

=pod

---++ callback_pong

=cut

sub callback_gotpong {
	my $this = shift;
	my $msg = shift;
	
	if($this->{'sent ping nonce'} eq $msg->payload() ){
		warn "got pong and it matches";
		$this->{'sent ping nonce'} = undef;
		$this->{'last pinged'} = time();
		return 1;
	}
	else{
		warn "bad pong received\n";
		$this->mark_finished();
		return undef;
	}
	
}




=pod

---+ Read/Write

=cut


=pod

---++ read_data

Take an opportunity after processing to see if there is a need to close this connection based on bad data from the peer.

=cut

sub read_data {
	use POSIX qw(:errno_h);
	
	my $this = shift;
	
	$this->{'bytes'} = '' unless defined $this->{'bytes'};
	my $n = sysread($this->socket(),$this->{'bytes'},8192,length($this->{'bytes'}));

	if (!defined($n) && $! == EAGAIN) {
		# would block
		warn "socket is blocking, so skip\n";
	}
	elsif($n == 0){
		warn "Closing peer, socket was closed from the other end.\n";
		$this->finish();
	}
	else{
		$this->bytes_read($n);
		warn "Have ".$this->bytes_read()." bytes read into the buffer\n";

		
		while($this->read_data_parse_msg()){
			warn "Trying to parse another message\n";
		}
		
		if($this->is_marked_finished()){
			$this->finish();
		}
	}
	return undef;
	
}

=pod

---++ read_data_parse_msg()->0/1

Parse the bytes we have till we can't parse anymore.

=cut

sub read_data_parse_msg {
	my $this = shift;
	
	
	foreach my $key (@{$this->{'message definition order'}}){
		#warn "reading in data for $key\n";
		return 0 unless $this->read_data_single_msg_item($key);
	}

	my $msg = CBitcoin::Message->new($this->{'buffer'});
	$this->{'buffer'} = {};
	
	if($msg->command eq 'version'){
		warn "Getting Message=".ref($msg)."\n";
		return $this->callback_gotversion($msg);
		
	}
	elsif($msg->command eq 'verack'){
		return $this->callback_gotverack($msg);
		
	}
	elsif($msg->command eq 'ping'){
		return $this->callback_gotping($msg);
		
	}
	elsif($this->handshake_finished()){
		warn "Got message of type=".$msg->command."\n";
		if(
			defined $callback_mapper->{'command'}->{$msg->command()}
			&&  ref($callback_mapper->{'command'}->{$msg->command()}) eq 'HASH'
			&& defined $callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}
			&& ref($callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}) eq 'CODE'
		){
			warn "Running subroutine for ".$msg->command()."\n";
			return $callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}->($this,$msg);
			
		}
		else{
			warn "Not running subroutine for ".$msg->command()."\n";
			return 1;
		}
	}
	else{
		warn "bad client behavior\n";
		return 0;
	}
	
}

=pod

---++ read_data_single_msg_item->0/1

Return 1 for keep going, return 0 for stop since we don't have any more bytes to read.

=cut

sub read_data_single_msg_item {
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
	elsif(defined $this->{'buffer'}->{$key}){
		# skip this
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
	return length($this->{'bytes to write'}) unless defined $data && length($data) > 0;
	$this->{'bytes to write'} .= $data;
	warn "Added ".length($data)." bytes to the write queue\n";
	return length($this->{'bytes to write'});
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