package CBitcoin::Peer;

use strict;
use warnings;

use CBitcoin;
use CBitcoin::Message; 
use CBitcoin::Utilities;
use Log::Log4perl;

use constant BUFFSIZE => 8192*4;


my $logger = Log::Log4perl->get_logger();
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
	#$logger->debug("1");
	$this = $this->init(@_);
	#$logger->debug("2");
	#$logger->debug("3");
	
	$logger->debug("Added Peer with address=".$this->address());
	
	return $this;
}

=pod

---++ init($options)

Overload this subroutine when overloading this class.

=cut

sub init {
	my $this = shift;
	my $options = shift;
	
	
	#$logger->debug("0");
	die "no options given" unless defined $options && ref($options) eq 'HASH' && defined $options->{'address'} && defined $options->{'port'} 
		&& defined $options->{'our address'} && defined $options->{'our port'} && defined $options->{'socket'} && fileno($options->{'socket'}) > 0;
	
	die "need spv base" unless defined $options->{'spv'};
	#$logger->debug("1");
	$options->{'block height'} ||= 0;
	$options->{'version'} ||= 70012; 
	$options->{'magic'} = 'MAINNET' unless defined $options->{'magic'};
	
	die "no good ip address given" unless CBitcoin::Utilities::ip_convert_to_binary($options->{'address'})
		&& CBitcoin::Utilities::ip_convert_to_binary($options->{'our address'});
	#$logger->debug("2");
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
		'read buffer size' => $options->{'read buffer size'},
		'rate limiting' => {
			'size' => 0,
			'time' => time(),
			'limit' => 3000, # bytes per second
			'interval' => 60
		}
	};
	$this->{'read buffer size'} ||= 8192;
	
	bless($this,$ref);
	
	
	# to have some human readable stuff for later
	chomp($options->{'address'}); 
	$this->{'address'} = $options->{'address'};
	$this->{'port'} = $options->{'port'};
	
	#$logger->debug("3");
	$this->{'handshake'}->{'our version'} = $this->version_serialize(
		$options->{'address'},$options->{'port'},
		$options->{'our address'},$options->{'our port'},
		time(),$options->{'version'},$options->{'block height'}
	); 
	#$logger->debug("4");
	$this->send_version();
	#$logger->debug("5");
	#die "Socket=".fileno($options->{'socket'})."\n";




	# set up the speed mechanism
	# ..updated in bytes_read
	# we keep track of th last 3 checkpoints only
	$this->{'stats'}->{'speed'} = {
		'checkpoints' => [[time(),0],[time(),0],[time(),0]]
		,'current' => 0
	};



	return $this;
}


=pod

---++ finish

Call this subroutine to disconnect and delete this peer.

=cut

sub finish {
	my $this = shift;
	$logger->debug("1");
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
		#warn "\n";
		$logger->info("handshake is finished, ready to run hooks");
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
	my ($this,$x) = @_;
	
	if(defined $x){
		$this->{'block height'} = $x;
	}
	
	
	return $this->{'block height'};
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

---++ chain

=cut

sub chain {
	return shift->spv->chain();
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
	my $errmsg = '';
	foreach my $key (@ver_order){
		my $size = $vers_size->{$key};
		
		if($size == -2){
			# need to read var_str
			$version->{$key} = CBitcoin::Utilities::deserialize_varstr($fh);
			#warn ."\n";
			$logger->debug("Reading var string with result=".$version->{$key});
			next;
		}
		
		$n = read($fh,$buf,$vers_size->{$key});
		$version->{$key} = $buf;
		#warn ."\n";
		$errmsg .= "For $key, got n=$n and value=".unpack('H*',$buf)."\n";
		
		
		unless($n == $vers_size->{$key}){
			$logger->error("bad bytes, size does not match");
			return undef;
		}
		
	}
	$logger->debug($errmsg);
	
	# version, should be in this range
	#  && unpack('l',$version->{'version'}) < 90000 
	unless(70000 < unpack('l',$version->{'version'})){
		$logger->error("peer supplied bad version number");
		return undef;
	}
	# services
	if($version->{'services'} & pack('Q',1)){
		#warn "NODE_NETWORK \n";
		$logger->debug("NODE_NETWORK");
	}
	else{
		$logger->debug("Just provides headers");
	}
	# timestamp, should not be more than 5 minutes old
	my $timediff = time () - unpack('q',$version->{'timestamp'});
	if(abs($timediff) < 1*60 ){
		$logger->debug("peer time is within error bound, diff=$timediff seconds");
	}
	else{
		#warn "\n";
		$logger->debug("peer time is too far off, diff=$timediff seconds");
	}
	# addr_recv
	$version->{'addr_recv'} = CBitcoin::Utilities::network_address_deserialize_forversion($version->{'addr_recv'});
	# addr_from
	$version->{'addr_from'} = CBitcoin::Utilities::network_address_deserialize_forversion($version->{'addr_from'});
	# nonce
	# make sure we don't have another peer with the same nonce?
	
	# blockheight (do sanity check)
	$version->{'block_height'} = unpack('l',$version->{'block_height'});
	$logger->debug("Got peer with blockheight=".$version->{'block_height'});
	unless(0 <= $version->{'block_height'}){
		$logger->error("bad block height of ".$version->{'block_height'});
		return undef;
	}
	$this->block_height($version->{'block_height'});
	
	# bool for relaying, should we relay
	#warn "."\n";
	$logger->debug("Relay=".unpack('C',$version->{'relay'}));
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
	$x = CBitcoin::Utilities::generate_urandom(8);
	$logger->debug("nonce:".unpack('H*',$x));
	#warn "nonce=".unpack('H*',$x);
	$data .= $x;
	# user agent (null, no string)
	$x = CBitcoin::Utilities::serialize_varstr($this->spv->client_name());
	#$x = CBitcoin::Utilities::serialize_varstr('');
	
	#warn "user agent=".unpack('H*',$x);
	$logger->debug("");
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

	my $this = shift;
	
	$this->{'bytes'} = '' unless defined $this->{'bytes'};
	my $socket = $this->socket();
	
	unless(0 < fileno($socket)){
		$this->finish();
		return undef;
	}
	
	my $n = sysread(
		$this->socket(),$this->{'bytes'},
		$this->{'read buffer size'},
		length($this->{'bytes'})
	);
	
	if(defined $n && $n == 0){
		$logger->debug("Closing peer, socket was closed from the other end.");
		$this->finish();
	}
	elsif(defined $n && 0 < $n){
		$this->bytes_read($n);
		$logger->debug("Have ".$this->bytes_read()." bytes read into the buffer");
		$this->{'rate limiting'}->{'size'} += $n;


		while(my $msg = $this->read_data_parse_msg()){
			$logger->debug("Got command=".$msg->command());
			if($msg->command eq 'version'){
				$this->callback_gotversion($msg);
			}
			elsif($msg->command eq 'verack'){
				$this->callback_gotverack($msg);
			}
			elsif($msg->command eq 'ping'){
				$this->callback_gotping($msg);
			}
			elsif($this->handshake_finished()){
				$this->spv->callback_run($msg,$this);
			}
			elsif(!$this->handshake_finished() && $msg->command eq 'reject'){
				my $payload = $msg->payload();
				open(my $fh,'<',\$payload);
				my $message = CBitcoin::Utilities::deserialize_varstr($fh);
				my ($n,$buf);
				$n = read($fh,$buf,1);
				my $ccode = unpack('C',$buf);
				my $reason = CBitcoin::Utilities::deserialize_varstr($fh);
				close($fh);
				
				$logger->error("Version rejected:\n.....message=[$message]\n.....ccode=[$ccode]\n.....reason=[$reason]");
				
				$this->mark_finished();
			}
			else{
				$logger->debug("marking peer as finished");
				$this->mark_finished();
			}
		}
		
		if($this->is_marked_finished()){
			$logger->debug("marked finished");
			$this->finish();
		}
		else{
			$this->spv->hook_peer_onreadidle($this);
		}
	}
	else{
		# would block
		$logger->debug("socket is blocking, so skip, error=".$!);
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
		substr($this->{'bytes'},0,$size) = ''; # delete  bytes we don't need
		$this->{'bytes read'} = $this->{'bytes read'} - $size;
		die "sizes do not match" unless $this->{'bytes read'} == length($this->{'bytes'});
		return 1;
	}
	elsif(defined $this->{'buffer'}->{$key}){
		# skip this
#		$logger->debug("skip key=$key");
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
	return shift->{'socket'};
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

---++ speed

The number of bytes downloaded between to sysread calls divided by the time interval.

=cut

sub speed {
	return shift->{'stats'}->{'speed'}->{'current'};
}

=pod

---++ bytes_read

Updates the current download speed.

=cut

sub bytes_read{
	my $this = shift;
	my $newbytes = shift;
	if(defined $newbytes && $newbytes > 0){
		$this->{'bytes read'} += $newbytes;  #implies undefined means 0
		
		#my $t_0 = $this->{'stats'}->{'speed'}->{'lasttime'};
		#$this->{'stats'}->{'speed'}->{'bytes'} = $newbytes;
		
		# take weighted average of the last 3 checkpoints
		my @w = (10,4,1);
		# delete the oldest point, prepend the newest checkpoint
		delete $this->{'stats'}->{'speed'}->{'checkpoints'}->[-1];
		unshift(@{$this->{'stats'}->{'speed'}->{'checkpoints'}},[time(),$newbytes]);
		my ($s,$tw) = (0,0);
		for(my $i=0;$i<3;$i++){
			$s += 1.0*$w[$i] * $this->{'stats'}->{'speed'}->{'checkpoints'}->[$i];
			$tw += 1.0*$w[$i]; 
		}
		$s = $s / $tw;
		$this->{'stats'}->{'speed'}->{'current'} = $s;
		
		
		
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
	
	if(!$this->{'sleeping'} && $this->write_data() == 0 && 0 < fileno($this->socket)){
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
	
	# check for rate limiting
	my $rlref = $this->{'rate limiting'};
	my $diff = (time() - $rlref->{'time'});
	if(0 < $rlref->{'size'} && 0 < $diff && $diff < $rlref->{'interval'}){
		# have written data, do check
		my $rate = (1.0 * $rlref->{'size'})/$diff;
		if($rlref->{'limit'} < $rate){
			# sending out too much data
			warn "sending too much data, take a break.\n";
			#die "stop";
			#$this->{'sleeping'} = 1;
			#$this->spv->peer_sleep($this,15);
			#return undef;
		}
	}
	elsif($rlref->{'interval'} < $diff){
		$rlref->{'size'} = 0;
	}
	
	unless(0 < fileno($this->socket())){
		$this->finish();
		return undef;
	}
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
		
		$this->{'rate limiting'}->{'size'} += $n;
		
		return $n;		
	}
	
}

=pod

---+ Sending Messages

The logic used to figure out what needs to be uploaded and downloaded is stored here.

=cut

=pod

---++ send_tx($tx)

Send a tx out.  Please avoid sending out the same transaction to the same peer multiple times.

=cut

sub send_tx {
	my ($this,$tx) = @_;
	return undef unless defined $tx;
	
	my $basedir = $this->db_path();
	
	my $peerName = Digest::SHA::sha256_hex($this->address().':'.$this->port);
	my $peerfp = join('/',$basedir,'peers','active',$peerName);
	
	# my $sentdir = join('/',$basedir,'sent');
	
	# see if we have already sent this tx out
	# ..untaint
	my $hash_hex;
	if(unpack('H*',$tx->hash) =~ m/^([0-9a-fA-F]+)$/){
		$hash_hex = $1;
	}
	else{
		die "failed to get hash";
	}
	
	unless(-d join('/',$basedir,'sent',$hash_hex) ){
		# already sent
		$logger->debug("creating tx");
		mkdir(join('/',$basedir,'sent',$hash_hex)) || die "could not create directory";
	}
	
	if(-l join('/',$basedir,'sent',$hash_hex,$peerName)){
		$logger->debug("already sent tx");
		return undef;
	}
	
	symlink($peerfp,join('/',$basedir,'sent',$hash_hex,$peerName));
	
	return $this->write(CBitcoin::Message::serialize(
		$tx->serialize(),
		'tx',
		$this->magic
	));	
	
}


=pod

---++ send_getblocks()

Calculate the block locator based on the block headers we have, then send a message out.

This can only be run every 5 minutes per peer.

=cut

sub send_getblocks{
	my ($this) = @_;
	#warn "Checking get_blocks timeout\n";
	
	return undef if defined $this->{'command timeout'}->{'send_getblocks'}
		&& time() - $this->{'command timeout'}->{'send_getblocks'} < 5;
	
	$logger->debug("sending get_blocks");
	$this->{'command timeout'}->{'send_getblocks'} = time();

	return $this->write(CBitcoin::Message::serialize(
		$this->spv->calculate_block_locator($this),
		'getblocks',
		$this->magic
	));
}


=pod

---++ send_getheaders

Compare the spv's block height with the peer's.  Use that as a condition as to whether or not to fetch blocks/headers.

The timeout on this command is 10 minutes.

=cut

sub send_getheaders {
	my $this = shift;
	return undef if defined $this->{'command timeout'}->{'send_getblocks'}
		&& time() - $this->{'command timeout'}->{'send_getblocks'} < 5;
	
	$logger->debug("sending get_headers");
	$this->{'command timeout'}->{'send_getblocks'} = time();

	return $this->write(CBitcoin::Message::serialize(
		$this->spv->calculate_block_locator($this),
		'getheaders',
		$this->magic
	));
}

=pod

---++ send_version

=cut

sub send_version {
	my $this = shift;
	$this->{'sent version'} = 1;
	#$logger->debug("sending version:\n".unpack('H*',$this->our_version())."\n");
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
	$logger->debug("sending ping");
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
		$logger->debug("got pong and it matches");
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




1;