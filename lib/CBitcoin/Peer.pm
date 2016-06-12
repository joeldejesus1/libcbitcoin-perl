package CBitcoin::Peer;

use strict;
use warnings;
use CBitcoin::Message; 
use CBitcoin::Utilities;
use constant BUFFSIZE => 8192*4;

our $callback_mapper;


=pod

---+ constructors/destructors

=cut


=pod

--++ new($options)

   * Required: 'address', 'port', 'socket', 'our address', 'our port'
      * 'socket' must be an already open socket
   * Optional: 'block height', 'version', 'magic'

=cut

sub new {
	my $package = shift;
	my $this = {};
	bless($this,$package);
	$this = $this->init(shift);
	
	return $this;
}

=pod

---++ init($options)

Overload this subroutine when overloading this class.

=cut

sub init {
	my $this = shift;
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
	my $ref = ref($this);
	$this = {
		'handshake finished' => 0,'sent version' => 0, 'sent verack' => 0, 'received version' => 0, 'received verack' => 0,
		'buffer'=> {},
		'spv' => $options->{'spv'},
		'socket' => $options->{'socket'},
		'message definition' => {'magic' => 4,'command' => 12, 'length' => 4, 'checksum' => 4 },
		'message definition order' => ['magic','command', 'length', 'checksum','payload' ],
		'command buffer' => {},
		'receive rate' => [0,0] ,
		'read buffer size' => $options->{'read buffer size'}
	};
	$this->{'read buffer size'} ||= 8192;
	
	bless($this,$ref);
	# to have some human readable stuff for later 
	$this->{'address'} = $options->{'address'};
	$this->{'port'} = $options->{'port'};
	
	$this->{'handshake'}->{'our version'} = $this->version_serialize(
		$options->{'address'},$options->{'port'},
		$options->{'our address'},$options->{'our port'},
		time(),$options->{'version'},$options->{'block height'}
	); 
	$this->send_version();
	
	#die "Socket=".fileno($options->{'socket'})."\n";

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

=pod

---++ handshake_finished

=cut

sub handshake_finished{
	my $this = shift;
	
	if($this->{'handshake finished'}){
		#warn "handhsake is already finished\n";
		return 1;
	}
	
	if($this->sent_version && $this->sent_verack && $this->received_version && $this->received_verack){
		$this->{'handshake finished'} = 1;
		warn "handshake is finished, ready to run hooks\n";
		$this->spv->peer_hook_handshake_finished($this);
		return 1;
	}
	else{
		return 0;
	}
}

=pod

---++ sent_version

=cut

sub sent_version {
	return shift->{'sent version'};
}

=pod

---++ sent_verack

=cut

sub sent_verack {
	return shift->{'sent verack'};
}

=pod

---++ received_version

=cut

sub received_version {
	return shift->{'received version'};
}

=pod

---++ received_verack

=cut

sub received_verack {
	return shift->{'received verack'};
}

=pod

---++ address

=cut

sub address {
	return shift->{'address'};
}

=pod

---++ port

=cut

sub port {
	return shift->{'port'};
}

=pod

---++ spv

=cut

sub spv {
	return shift->{'spv'};
}

=pod

---++ block_height

Block height of peer at the time of handshake.

=cut

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

=pod

---++ magic

=cut

sub magic {
	return shift->{'magic'};
}

=pod

---++ our_version

=cut

sub our_version {
	return shift->{'handshake'}->{'our version'};
}



=pod

---+ Handshakes

=cut

=pod

---++ version_deserialize

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

=pod

---++ version_serialize

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
	$x = CBitcoin::Utilities::serialize_varstr($this->spv->client_name());
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





=pod

---+ Read/Write

=cut


=pod

---++ read_data

Take an opportunity after processing to see if there is a need to close this connection based on bad data from the peer.

=cut

sub read_data {
	use POSIX qw(:errno_h);
	warn "can read from peer";
	my $this = shift;
	
	$this->{'bytes'} = '' unless defined $this->{'bytes'};
	my $socket = $this->socket();
	warn "Socket=$socket\n";
	my $n = sysread(
		$this->socket(),$this->{'bytes'},
		$this->{'read buffer size'},
		length($this->{'bytes'})
	);
	warn "Read N=$n bytes";
	
	if(defined $n && $n == 0){
		#warn "Closing peer, socket was closed from the other end.\n";
		$this->finish();
	}
	elsif(defined $n && $n > 0){
		$this->bytes_read($n);
		#warn "Have ".$this->bytes_read()." bytes read into the buffer\n";

		while(my $msg = $this->read_data_parse_msg()){
			if($msg->command eq 'version'){
				#warn "Getting Message=".ref($msg)."\n";
				$this->callback_gotversion($msg);
				
			}
			elsif($msg->command eq 'verack'){
				$this->callback_gotverack($msg);
				
			}
			elsif($msg->command eq 'ping'){
				$this->callback_gotping($msg);
				
			}
			elsif($this->handshake_finished()){
				#push(@{$this->{'messages to be processed'}},$msg);
				#return 1;
				#$this->hook_callback($msg);
				$this->spv->callback_run($msg,$this);
			}
			else{
				#warn "bad client behavior\n";
				$this->mark_finished();
			}
		}
		
		$this->spv->hook_peer_onreadidle($this);
		
		if($this->is_marked_finished()){
			$this->finish();
		}
	}
	else{
		# would block
		#warn "socket is blocking, so skip, error=".$!."\n";
	}
	
	return undef;
	
}


=pod

---++ read_data_parse_msg()->$msg

Parse the bytes we have till we can't parse anymore.

=cut

sub read_data_parse_msg {
	my $this = shift;
	
	# order = ['magic','command', 'length', 'checksum','payload' ], double check if there is a problem
	foreach my $key (@{$this->{'message definition order'}}){
		#warn "reading in data for $key\n";
		return undef unless $this->read_data_single_msg_item($key);
	}

	my $msg = CBitcoin::Message->new($this->{'buffer'});
	$this->{'buffer'} = {};
	return $msg;	
}

=pod

---++ read_data_single_msg_item->0/1

Return 1 for keep going, return 0 for stop since we don't have any more bytes to read.

=cut

sub read_data_single_msg_item {
	my $this = shift;
	my ($key) = (shift);
	
	# order = ['magic','command', 'length', 'checksum','payload' ], double check if there is a problem
	my $size = $this->definition_size_mapper($key);
	die "key not defined" unless defined $size;
	
	
	if(!defined $this->{'buffer'}->{$key} &&  $size <= $this->{'bytes read'} ){
		$this->{'buffer'}->{$key} = substr($this->{'bytes'},0,$size);
		#warn "Pre $key=".unpack('H*',$this->{'buffer'}->{$key})."\n";
		substr($this->{'bytes'},0,$size) = ''; # delete  bytes we don't need
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

=pod

---++ definition_size_mapper

=cut

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

---++ socket

=cut

sub socket {
	my $this = shift;
	require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this);
	#open(my $fhout,'>','/tmp/bonus');
	#print $fhout $xo;
	#close($fhout);
	return $this->{'socket'};
}

=pod

---++ last_pinged

=cut

sub last_pinged {
	return shift->{'last pinged'};
}

=pod

---++ command_buffer

=cut

sub command_buffer {
	return shift->{'commands'}->{shift};
}

=pod

---++ bytes_read

=cut

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

=pod

---++ bytes

=cut

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

---++ write($data)

Add to the write queue.  Also adds a write flag to the event mask on the socket via the sub passed in the $spv constructor.

=cut

sub write {
	my $this = shift;
	my $data = shift;

	$data = '' unless defined $data;

	return length($this->{'bytes to write'}) unless defined $data && length($data) > 0;
	$this->{'bytes to write'} .= $data;
	
	#warn "Added ".length($data)." bytes to the write queue\n";
	
	if($this->write_data() == 0 && fileno($this->socket) > 0){
		$this->spv->mark_write($this->socket);
		return 0;
	}
	
	return length($this->{'bytes to write'});
}

=pod

---++ write_data()

When we can write data, send out BUFFSIZE bytes.

=cut

sub write_data {
	my $this = shift;
	
	use POSIX qw(:errno_h);

	
	unless( 0 < fileno($this->socket()) ){
		$this->mark_finished();
		return undef;
	}
	
	
	return undef unless defined $this->{'bytes to write'} && length($this->{'bytes to write'}) > 0;
	
	my $n = syswrite($this->socket(),$this->{'bytes to write'},BUFFSIZE);

	if (!defined($n) && $! == EAGAIN) {
		# would block
		#warn "socket is blocking, so skip\n";
		return 0;
	}
	elsif($n == 0){
		#warn "Closing peer, socket was closed from the other end.\n";
		$this->finish();
		return 0;
	}
	else{
		#warn "wrote $n bytes";
		substr($this->{'bytes to write'},0,$n) = "";
		return $n;		
	}
	
}

=pod

---+ Sending Messages

The logic used to figure out what needs to be uploaded and downloaded is stored here.

=cut


=pod

---++ send_getheaders

Compare the spv's block height with the peer's.  Use that as a condition as to whether or not to fetch blocks/headers.

The timeout on this command is 10 minutes.

=cut

sub send_getheaders {
	my $this = shift;
	return CBitcoin::Message::serialize(
			$this->spv->calculate_block_locator(),
			'getheaders',
			CBitcoin::Message::net_magic($this->magic)  # defaults as MAINNET
	);
	
}

=pod

---++ send_version

=cut

sub send_version {
	my $this = shift;
	$this->{'sent version'} = 1;
	return $this->write(CBitcoin::Message::serialize($this->our_version(),'version'));
}

=pod

---++ send_verack

=cut

sub send_verack {
	my $this = shift;
	$this->{'sent verack'} = 1;
	return $this->write(CBitcoin::Message::serialize('','verack',$this->magic));
}

=pod

---++ send_ping

=cut

sub send_ping {
	my $this = shift;
	warn "Sending ping\n";
	$this->{'sent ping nonce'} = CBitcoin::Utilities::generate_random(8);
	
	return $this->write(CBitcoin::Message::serialize($this->{'sent ping nonce'},'ping',$this->magic));
}

=pod

---++ send_pong

=cut

sub send_pong {
	my $this = shift;
	my $nonce = shift;
	die "bad nonce" unless defined $nonce && length($nonce) == 8;
	#warn "Sending pong\n";
	return $this->write(CBitcoin::Message::serialize($nonce,'pong',$this->magic));
}

=pod

---++ send_getblocks()

Calculate the block locator based on the block headers we have, then send a message out.

=cut

sub send_getblocks{
	my ($this) = @_;

	return undef if defined $this->{'command timeout'}->{'send_getblocks'}
		&& time() - $this->{'command timeout'}->{'send_getblocks'} < 60*1;

	$this->{'command timeout'}->{'send_getblocks'} = time();

	return $this->write(CBitcoin::Message::serialize(
		$this->spv->calculate_block_locator(),
		'getblocks',
		$this->magic
	));
}



=pod

---++ send_getaddr

Ask for info on more peers.

=cut

sub send_getaddr{
	my ($this) = @_;
	#warn "sending getaddr\n";
	return $this->write(CBitcoin::Message::serialize(
		'',
		'getaddr',
		$this->magic
	));
}


=pod

---++ send_getdata($invpayload)

Given a payload, go get some data.  This is called in callback_gotinv

=cut

sub send_getdata{
	my ($this,$payload) = @_;
	
	return undef unless defined $payload && 0 < length($payload);

	return $this->write(CBitcoin::Message::serialize(
		$payload,
		'getdata',
		$this->magic
	));
}


=pod

---+ Callbacks

When a message is recieved, the command is parsed from the message and used to fetch the subroutine, which is stored in the global hash $callback_mapper.

=cut


=pod

---++ callback_gotaddr

Store the new addr in the peer database.

=cut

BEGIN{
	$callback_mapper->{'command'}->{'addr'} = {
		'subroutine' => \&callback_gotaddr
	}
};

sub callback_gotaddr {
	my $this = shift;
	my $msg = shift;
	#warn "gotaddr\n";
	open(my $fh,'<',\$msg->{'payload'});
	my $addr_ref = CBitcoin::Utilities::deserialize_addr($fh);
	close($fh);
	if(defined $addr_ref && ref($addr_ref) eq 'ARRAY'){
		#warn "Got ".scalar(@{$addr_ref})." new addresses\n";
		
		foreach my $addr (@{$addr_ref}){
			# timestamp, services, ipaddress, port
			$this->spv->add_peer_to_inmemmory(
				$addr->{'services'},
				$addr->{'ipaddress'},
				$addr->{'port'}
			);
		}
		
		
	}
	else{
		#warn "Got no new addresses\n";
	}
	return 1;
	
}


=pod

---++ callback_gotversion

Used in the handshake between peers.

=cut

sub callback_gotversion {
	my $this = shift;
	my $msg = shift;
	
	# handshake should not be finished
	if($this->handshake_finished()){
		#warn "peer already finished handshake, but received another version\n";
		$this->mark_finished();
		return undef;
	}
	
	# we should not already have a version
	if($this->received_version()){
		#warn "peer already sent a version\n";
		$this->mark_finished();
		return undef;
	}


	# parse version	
	unless($this->version_deserialize($msg)){
		#warn "peer sent bad version\n";
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

Used in the handshake.

=cut

sub callback_gotverack {
	my $this = shift;
	
	
	# we should not have already received a verack
	if($this->received_verack()){
		#warn "bad peer, already received verack";
		$this->mark_finished();
		return undef;
	}
	
	# we should have sent a version
	if(!$this->sent_version()){
		#warn "no version sent, so we should not be getting a verack\n";
		$this->mark_finished();
		return undef;
	}
	
	$this->{'received verack'} = 1;
	
	$this->send_ping();
	return 1;
}

=pod

---++ callback_ping

Used after a timeout has been reached, to confirm that the connection is still up.

=cut

sub callback_gotping {
	my $this = shift;
	my $msg = shift;
	#warn "Got ping\n";
	unless($this->handshake_finished()){
		#warn "got ping before handshek finsihed\n";
		$this->mark_finished();
		return undef;
	}
	$this->send_pong($msg->payload());
	return 1;
}

=pod

---++ callback_pong

Sent by a peer in response to a ping sent by us.

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
		#warn "bad pong received\n";
		$this->mark_finished();
		return undef;
	}
	
}


=pod

---++ callback_gotinv

Used when inventory vectors have been received.  The next step is to fetch the corresponding content via getdata.  See hook_getdata for information on how getdata is handled.

=cut

BEGIN{
	$callback_mapper->{'command'}->{'inv'} = {
		'subroutine' => \&callback_gotinv
	}
};

sub callback_gotinv {
	my $this = shift;
	my $msg = shift;
	warn "Got inv\n";
	unless($this->handshake_finished()){
		#warn "got inv before handshake finsihed\n";
		$this->mark_finished();
		return undef;
	}
	open(my $fh,'<',\($msg->payload()));
	binmode($fh);
	my $count = CBitcoin::Utilities::deserialize_varint($fh);
	warn "gotinv: count=$count\n";
	for(my $i=0;$i < $count;$i++){
		$this->spv->hook_inv(@{CBitcoin::Utilities::deserialize_inv($fh)});
	}
	close($fh);
		
	# go fetch the data
	$this->send_getdata($this->spv->hook_getdata());
	
}


=pod

---++ callback_gotblock

Got a block, so put it into the database.


---+++ Tx Format
version
inputs => [..]
outputs => [..]
locktime

input = {prevHash, prevIndex, script, sequence}
output = {value, script}


=cut

BEGIN{
	$callback_mapper->{'command'}->{'block'} = {
		'subroutine' => \&callback_gotblock
	}
};

sub callback_gotblock {
	my $this = shift;
	my $msg = shift;
	
	
	# write this to disk
	my $fp = '/tmp/spv/tmp.'.$$.'.block';
	open(my $fh,'<',\($msg->payload()));
	if( 100_000 < length($msg->payload()) ){
		open(my $fhout,'>',$fp) || die "cannot write to disk";
		binmode($fh);
		binmode($fhout);
		
		my ($n,$buf);
		while($n = read($fh,$buf,8192)){
			my $m = 0;
			while(0 < $n - $m){
				$m += syswrite($fhout,$buf,$n - $m,$m);
			}
		}
		close($fhout);
		close($fh);
		open($fh,'<',$fp) || die "cannot read from disk";		
	}
	
	eval{
		
		my $block = CBitcoin::Block->deserialize($fh);
		
		#warn "Got block with hash=".$block->hash_hex().
		#	" and transactionNum=".$block->transactionNum.
		#	" and prevBlockHash=".$block->prevBlockHash_hex()."\n";
		my $count = $block->transactionNum;
		#die "let us finish early\n";
		$this->spv->add_header_to_chain($block);
		
		if(0 < $count){
			for(my $i=0;$i<$count;$i++){
				#warn "looping\n";		
				$this->spv->add_tx_to_db(
					$block->hash(),
					CBitcoin::Transaction->deserialize($fh)
				);
			}
		}
		else{
			die "weird block\n";
		}
		
		# delete it in inv search.
		delete $this->spv->{'inv search'}->[2]->{$block->hash()};
		
	} || do {
		my $error = $@;
		warn "Error:$error\n";
	};
	
	
	#$this->spv->{'inv'}->[2]->{$block->hash()} = $block;
	unlink($fp) if -f $fp;
}

=pod

---+ hooks

=cut

=pod

---++ hook_callback($msg)

Take the command out of a message, and map it to a subroutine.

=cut

sub hook_callback{
	my $this = shift;
	my $msg = shift;
	
	#warn "Got message of type=".$msg->command."\n";
	if(
		defined $callback_mapper->{'command'}->{$msg->command()}
		&&  ref($callback_mapper->{'command'}->{$msg->command()}) eq 'HASH'
		&& defined $callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}
		&& ref($callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}) eq 'CODE'
	){
		#warn "Running subroutine for ".$msg->command()."\n";
		return $callback_mapper->{'command'}->{$msg->command()}->{'subroutine'}->($this,$msg);
		
	}
	else{
		#warn "Not running subroutine for ".$msg->command()."\n";
		return 1;
	}
}

1;