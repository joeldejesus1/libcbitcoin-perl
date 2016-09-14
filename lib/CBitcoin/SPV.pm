package CBitcoin::SPV;

use strict;
use warnings;


use CBitcoin::Message;
use CBitcoin::Utilities;
use CBitcoin::Peer;
use CBitcoin::Block;
use CBitcoin::Chain;

use Net::IP;
use Fcntl ':flock'; # Import LOCK_* constants
use Log::Log4perl;



=pod

---+ contructors/destructors

=cut


my $logger = Log::Log4perl->get_logger();
our $callback_mapper;


=pod

---++ new($options)

Create a new SPV client.

=cut

sub new {
	my $package = shift;
	my $options = shift;
	$options = {} unless defined $options;
	
	my $this = {};
	bless($this,$package);
	$this->init($options);

	
	$this->{'getblocks timeout'} = 0;
	$this->{'callbacks nonce'} = 1;
	
	$this->make_directories();
	
	# start block chain at 0
	$this->{'headers'} = [];
	$this->{'transactions'} = {};
	$this->initialize_chain();

	
	# brain
	$this->{'inv'} = [{},{},{},{}];
	$this->{'inv search'} = [{},{},{},{}];
	$this->{'inv next getdata'} = [ [], [], [], []];	
	$this->initialize_peers();
	
	# allow outside processes to send and receive messages with this spv process
	$this->initialize_cnc();
	
	
	
	warn "spv new done";

	return $this;
	
}


=pod

---++ finish()

=cut

sub finish {
	my ($this) = @_;
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	$logger->info("Removing SPV object of pid=$our_pid and uid=$our_uid");
	unlink('/dev/mqueue/'.join('.','spv',$our_uid,$our_pid));
}

sub DESTROY {
	shift->finish();
}


=pod

---++ init($options)

Overload this subroutine.

=cut

sub init {
	my ($this,$options) = @_;
	
	my $el = $options->{'event loop'};
	if(defined $el && $el ){
		# assign relevant anonymous subs
		$options->{'mark write sub'} = $el->mark_write();
		$options->{'connect sub'} = $el->connect();
	}
	else{
		die "there is no event loop code";
	}
	
	
	$options->{'version'} = 70001 unless defined $options->{'version'};
	
	$options->{'db path'} = '/tmp/spv' unless defined $options->{'db path'} && -e $options->{'db path'};
	

	$options->{'last getaddr'} = 0;
	
	# config settings
	
	# ..max connections
	if(defined $options->{'max connections'} && $options->{'max connections'} =~ m/^(\d+)$/){
		$options->{'max connections'} = $1;
	}
	elsif(!defined $options->{'max connections'}){
		$options->{'max connections'} = 2;
	}
	else{
		die "bad max connection setting";
	}
	
	$options->{'read buffer size'} = 8192 unless
		defined $options->{'read buffer size'} && $options->{'read buffer size'} =~ m/^\d+$/;
	
	
	foreach my $key (keys %{$options}){
		$this->{$key} = $options->{$key};
	}
	
	$logger->debug("Client Name=[".$this->{'client name'}."]");
	
	
	$this->add_bloom_filter($options->{'bloom filter'});


	# stats, speed
	$this->{'stats'}->{'speed'}->{'current'} = 0;
	
}



=pod

---++ make_directories

=cut

sub make_directories{
	my $this = shift;
	my $base = $this->{'db path'};
	
	# untaint the db path (TODO: make a better regex for this)
	if($base =~ m/^(.*)$/){
		$base = $1;
	}
	
	
	mkdir($base) unless -d $base;
	
	# ./peers
	mkdir("$base/peers") unless -d "$base/peers";
	mkdir("$base/peers/pool") unless -d "$base/peers/pool";
	mkdir("$base/peers/active") unless -d "$base/peers/active";
	mkdir("$base/peers/banned") unless -d "$base/peers/banned";
	mkdir("$base/peers/pending") unless -d "$base/peers/pending";
	
	# ./pending
	mkdir("$base/pending") unless -d "$base/pending";
	
	# ./locators
	mkdir("$base/locators") unless -d "$base/locators";
	
	
	# ./headers
	mkdir("$base/headers") unless -d "$base/headers";	
	
	# ./blocks
	mkdir("$base/blocks") unless -d "$base/blocks";
	
	
}

=pod

---++ initialize_cnc

The command and control file is /tmp/spv/cnc.

# current checkpoint height

=cut

sub initialize_cnc {
	my ($this) = @_;
	
	$this->{'cnc queues'} = {
		
	};
	
	$this->event_loop->cncstdio_add($this);
	$this->event_loop->cncspv_own($this);
	$this->event_loop->cncspv_add($this);
	
	# look for other spv processes
	foreach my $pid (@{$this->event_loop->spv_pids()}){
		$logger->debug("Got pid=$pid");
		$this->{'cnc queues'}->{$pid} = [];
	}
	
	
	# broadcast to other spv processes that we exist
	$this->cnc_broadcast_message(CBitcoin::Message::serialize($$,'custaddspv',$CBitcoin::network_bytes));
	
	return undef;	
}


=pod

---++ initialize_peers

Move any peers in active to pool

=cut

sub initialize_peers {
	my ($this) = @_;
	my $base = $this->{'db path'};
	my $fp_active = "$base/peers/active";
	my $fp_pool = "$base/peers/pool";
	
	
	opendir(my $fh,$fp_active);
	my @files = readdir($fh);
	closedir($fh);
	foreach my $f1 (@files){
		if($f1 =~ m/^([0-9a-zA-Z]+)$/){
			$f1 = $1;
		}
		else{
			next;
		}
		
		rename("$fp_active/$f1", "$fp_pool/$f1") 
			|| die "Move $fp_active/$f1 -> $fp_pool/$f1 failed: $!";
	}
}

=pod

---+ chain management

=cut

=pod

---++ initialize_chain

Save the genesis block into block headers.  Also, create the first block locator for use in getheaders.

=cut

sub initialize_chain{
	my $this = shift;
	my $base = $this->db_path();

	$logger->info("initialize chain");
	
	
	$this->{'chain db'} = CBitcoin::Chain->new({
		'path' => $this->db_path
		,'genesis block' => CBitcoin::Block->genesis_block()
	});
	
	
	
	return 1;
}


=pod

---++ checkpoint_save

=cut

sub checkpoint_save {
	my ($this) = @_;
	
	$this->chain->save();
}

=pod

---++ add_header_to_chain($block)

Directory: $dbpath/headers/hash1/hash2/hash3/

In the directory:
	./prevBlockHash (binary format)
	./data (serialized header with tx count set to 0)
	
=cut

sub add_header_to_chain {
	my ($this,$peer, $block_header) = @_;
	die "header is null" unless defined $block_header;
	
	#$this->add_header_to_inmemory_chain($peer, $block_header);

	if($this->chain->block_append($block_header)){
		$this->chain->block_orphan_save();
		$this->add_header_to_db($block_header);
	}
	else{
		# this block as already been appended
#		$logger->debug("this block has already been appended");
	}
}


=pod

---++ calculate_block_locator($hash_stop)

Go through the in-memory chain, and create the block_locator hash array.  Return a serialized message.

=cut

sub calculate_block_locator {
	my ($this,$peer,$hash_stop) = @_;
	
	
	
	# 32 bytes of null
	unless(defined $hash_stop){
		$hash_stop = pack('x');
		foreach my $i (2..32){
			$hash_stop .= pack('x');
		}
	}
	
	my $arrayref = $this->chain->block_locator();
	die "no block locator" unless defined $arrayref && ref($arrayref) eq 'ARRAY' && 0 < scalar(@{$arrayref});
	
	
	return pack('L',$this->version).CBitcoin::Utilities::serialize_varint(scalar(@{$arrayref})).
		join('',@{$arrayref}).$hash_stop;
}

=pod

---+ database

=cut

=pod

---++ add_header_to_db($header)

=cut

sub add_header_to_db {
	my ($this, $header) = @_;
	
	#$logger->debug("New header with hash=".unpack('H*',$header->hash));
	
	$this->cncout_send_header($header);
}

=pod

---++ add_tx_to_db($block_hash,$tx)

Given a block hash and a transaction, do something.

=cut

sub add_tx_to_db {
	my ($this,$block_hash,$tx) = @_;

	#warn ."\n";
	$logger->debug("Tx with inputs=".scalar(@{$tx->{'inputs'}})." and outputs=".
		scalar(@{$tx->{'outputs'}}));

}

=pod

---++ add_peer_to_db($peer)

=cut

sub add_peer_to_db {
	my ($this,$peer) = @_;
	
	#warn "Got Peer in database\n";
	$logger->debug("Got Peer in database")
}

=pod

---+ Getters/Setters

=cut

=pod

---++ db_path

=cut

sub db_path {
	return shift->{'db path'};
}

=pod

---++ event_loop

=cut

sub event_loop{
	return shift->{'event loop'};
}

=pod

---++ chain

=cut

sub chain {
	return shift->{'chain db'};
}


=pod

---++ version

=cut

sub version {
	return shift->{'version'};
}

=pod

---++ peers_path

=cut

sub peers_path {
	return shift->{'db path'}.'/peers';
}

=pod

---++ peer_pool_count

How many peer addresses are there to connect to?

=cut

sub peer_pool_count {
	my ($this) = @_;
		
	opendir(my $fh,$this->db_path().'/peers/pool');
	my @f = readdir($fh);
	closedir($fh);
	return (scalar(@f) - 2);
}

=pod

---++ peer_set_sleepsub($socket,$sub)

This sub is a little tricky, checkout 00-spv.t

=cut

sub peer_set_sleepsub {
	my ($this,$socket,$sub) = @_;
	
	return undef unless defined $socket && 0 < fileno($socket);
	return undef unless defined $sub && ref($sub) eq 'CODE';
	
	$logger->debug("1");
	my $peer = $this->peer_by_fileno(fileno($socket));
	$this->{'peer sleepsub'}->{fileno($socket)} = sub{
		my $p2 = $peer;
		my $sub2 = $sub;
		$sub2->($p2,@_);
	};
}

=pod

---++ peer_sleep($peer,$timeout)

Put a peer to sleep when the data transmission rate has been exceeded.

=cut

sub peer_sleep {
	my ($this,$peer,$timeout) = @_;
	
	warn "putting peer to sleep for $timeout";
	# set 60 second timeout on EV::WRITE
	$this->{'peer sleepsub'}->{fileno($peer->socket())}->($timeout);
}

=pod

---++ max_connections

=cut

sub max_connections {
	return shift->{'max connections'};
}

=pod

---++ mark_write

=cut

sub mark_write {
	my $this = shift;
	my $socket = shift;
	#warn "doing mark write\n";
	return $this->{'mark write sub'}->($socket);
}

=pod

---++ is_marked_getblocks

=cut

sub is_marked_getblocks{
	my ($this,$x) = @_;
	if(defined $x){
		$this->{'marked getblocks'} = $x;
	}
	return $this->{'marked getblocks'};
}

=pod

---++ block

=cut

sub block{
	my ($this,$index) = (shift,shift);
	die "bad index given" unless
		defined $index && $index =~ m/^(\d+)$/ && 0 <= $index;
	#$index = $index;
	
	$this->sort_chain();
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'headers'});
	#warn "XO=$xo\n"; 
	#warn "Returning block i=$index v=".unpack('H*',$this->{'headers'}->[$index])."\n"
	#	if defined $this->{'headers'}->[$index];
	return $this->{'headers'}->[$index];
}

=pod

---++ block_height

=cut

sub block_height {
	return shift->{'chain db'}->height();
}


=pod

---++ bloom_filter

=cut

sub bloom_filter {
	return shift->{'bloom filter'};
}

=pod

---++ our_address

=cut

sub our_address {
	my $this = shift;
	my $binarybool = shift;
	if($binarybool){
		return [CBitcoin::Utilities::ip_convert_to_binary($this->{'address'}),$this->{'port'}];
	}
	else{
		return [$this->{'address'},$this->{'port'}];
	}
	
}

=pod

---+ Peer Management

=cut


=pod

---++ add_bloom_filter

Basically, this is the "wallet" part of this module.

See callback_gotblock to see how the bloom filter is used.

=cut

sub add_bloom_filter {
	my ($this,$bf) = @_;
	die "not a bloom filter" unless defined $bf && ref($bf) =~ m/BloomFilter/;
	# calculates the bloom filter, dies if we have bad stuff.
	$bf->data();
	
	$this->{'bloom filter'} = $bf;
}


=pod

---++ activate_peer()

Find a peer in a pool, and turn it on

=cut

sub activate_peer {
	my $this = shift;
	$logger->debug("activating peer - 0");
	
	my $connect_sub = $this->{'connect sub'};
	# if we are maxed out on connections, then exit
	return undef unless scalar(keys %{$this->{'peers'}}) < $this->max_connections();
	die "not given connection sub" unless defined $connect_sub && ref($connect_sub) eq 'CODE';
	
	my $dir_pool = $this->db_path().'/peers/pool';
	my $dir_active = $this->db_path().'/peers/active';
	my $dir_pending = $this->db_path().'/peers/pending';
	my $dir_banned = $this->db_path().'/peers/banned';
	
	$logger->debug("activating peer - 2");
	opendir(my $fh,$dir_pool) || die "cannot open directory";
	my @files = grep { $_ ne '.' && $_ ne '..' } readdir $fh;
	closedir($fh);
	
	my @peer_files = sort @files;
	
	my $numOfpeers = scalar(@peer_files);
	
	
	if(0 < $numOfpeers && $numOfpeers < 5 && 60 < time() - $this->{'last getaddr'}){
		$this->{'last getaddr'} = time();
		
		# get a connected peer?
		#warn "not enough peers, add more\n";
		foreach my $fd (keys %{$this->{'peers'}}){
			$this->{'peers'}->{$fd}->send_getaddr();
		}
	}
	elsif($numOfpeers == 0){
		#die "ran out of nodes to connect to.";
		$logger->error("ran out of nodes to connect to.");
		return undef;
	}
	
	
	my ($latest,$socket);
	$logger->debug("activating peer - 3");
	
	while(scalar(@peer_files)>0){
		$latest = shift(@peer_files);
		#warn "Latest peer to try to connect to is hash=$latest\n";
		# untaint
		if("$latest" =~ m/^(.*)$/){
			$latest = $1;
		}
		
		
		eval{
			#warn "part 1\n";
			#$logger->debug("part 1");
			rename($dir_pool.'/'.$latest,$dir_pending.'/'.$latest) || die "alpha";
			
			# create connection
			open($fh,'<',$dir_pending.'/'.$latest) || die "beta";
			my @guts = <$fh>;
			close($fh);
			#warn "part 2\n";
			#$logger->debug("part 2");
			die "charlie" unless scalar(@guts) == 3;
			
			# connect with ip address and port
			# the connection logic is not here, that is left to the final program to decide
			# perhaps the end user wants to use tor, or a proxy to connect
			# so, let that logic be elsewhere, just send an anonymous subroutine
			$socket = $connect_sub->($this,$guts[1],$guts[2]);
			#warn "part 3 with socket=".fileno($socket)."\n";
			#$logger->debug("part 3 with socket=".fileno($socket));
			
			unless(defined $socket && fileno($socket) > 0){
				rename($dir_pending.'/'.$latest,$dir_banned.'/'.$latest);
				die "delta";
			}
			
			# we have a socket, ready to go
			#$logger->debug("part 3.1");
			$this->add_peer($socket,$guts[1],$guts[2]);
			#warn "part 4\n";
			#$logger->debug("part 4");
			rename($dir_pending.'/'.$latest,$dir_active.'/'.$latest);
			
		};
		my $error = $@;
		if($error){
			$logger->error("have to try another peer. Error=$error");
		}
		else{
			#warn "finished looping to find a new peer\n";
			$logger->debug("finished looping to find a new peer");
			last;
		}

	}
	
}

=pod

---++ add_peer_to_inmemmory($services,$addr_recv_ip,$addr_recv_port)

This adds a peer to a list of potential peers, but does not create a new connection.

File:
HEADERSONLY
ipaddrss
port

=cut

sub add_peer_to_inmemmory{
	
	my ($this,$services, $addr_recv_ip,$addr_recv_port) = (shift,shift,shift,shift);
	#warn "Adding peer to db ($addr_recv_ip,$addr_recv_port)\n";
	$logger->debug("Adding peer to db ($addr_recv_ip,$addr_recv_port)");
	
	my $filename = Digest::SHA::sha256_hex("$addr_recv_ip:$addr_recv_port");
	#warn "Filepath =".$this->db_path().'/peers/pool/'.$filename."\n";
	
	return undef if -f $this->db_path().'/peers/pool/'.$filename || -f $this->db_path().'/peers/active/'.$filename 
		|| -f $this->db_path().'/peers/banned/'.$filename;
	
	#warn "adding peer 2\n";
	my $fh;
	#if($this->db_path().'/peers/pool/'.$filename =~ m/^(.*)$/){
		
	#}
	open($fh, '>',$this->db_path().'/peers/pool/'.$filename) || die "cannot open file for peer\n";
	#warn "adding peer 3\n";
	if($services & pack('Q',1)){
		#warn "adding peer offering full blocks, not just headers\n";
		print $fh "FULLBLOCKS\n";
	}
	else{
		#warn "adding peer offering just headers\n";
		print $fh "HEADERSONLY\n";		
	}
	#warn "adding peer 4\n";
	print $fh "$addr_recv_ip\n$addr_recv_port\n";
	close($fh);
	#warn "adding peer 5\n";
	
	
	
	return 1;
}

=pod

---++ add_peer($socket,$addr_recv_ip,$addr_recv_port)

Mark that a peer has been connected to and that it is ready to do a handshake.

This is called by activate_peer.

For tor/onion addresses, use the following website:

https://lists.torproject.org/pipermail/tor-talk/2012-June/024591.html

=cut

sub add_peer{
	my ($this,$socket, $addr_recv_ip,$addr_recv_port) = @_;
	
	my $ref = $this->our_address();
	$logger->debug("0");
	my $peer = CBitcoin::Peer->new({
		'spv' => $this,
		'socket' => $socket,
		'address' => $addr_recv_ip, 'port' => $addr_recv_port,
		'our address' => $ref->[0], 'our port' => $ref->[1],
		'read buffer size' => $this->{'read buffer size'}
	});
	$logger->debug("1");
	# basically, this gets overloaded by an inheriting class
	$this->add_peer_to_db($peer);
	$logger->debug("2");

	#$this->cnc_send_message('cnc out','new peer:'.$peer->address);

	# go by fileno, it is friendly to IO::Epoll
	$this->{'peers'}->{fileno($socket)} = $peer;
	$this->{'peers by address:port'}->{$addr_recv_ip}->{$addr_recv_port} = $peer;
	
	return 1;
}

=pod

---++ client_name

Overload this.

=cut

sub client_name {
	my ($this) = @_;
	$this->{'client name'} = '/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/' unless defined $this->{'client name'};
	return $this->{'client name'};
}


=pod

---++ peer($ipaddress,$port)

=cut

sub peer{
	my $this = shift;
	my ($ipaddress, $port) = (shift,shift);
	if(defined $this->{'peers by address:port'}->{$ipaddress}){
		return  $this->{'peers by address:port'}->{$ipaddress}->{$port};
	}
	return undef;
}

=pod

---++ peer_by_fileno($fileno_of_socket)

=cut

sub peer_by_fileno {
	my $this = shift;
	my $fileno = shift;
	#warn "peer_by_fileno=$fileno\n with glob=".ref($this->{'peers'}->{$fileno})."\n";
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'peers'});
	#open(my $fhout,'>','/tmp/bonus2');
	#print "peer_by_fileno\n";
	#print $fhout $xo;
	#close($fhout);
	return $this->{'peers'}->{$fileno};
}

=pod

---++ close_peer($fileno_of_socket)

=cut

sub close_peer {
	my ($this,$fileno) = @_;
	return undef unless defined $fileno;
	# TODO: untaint everything!
	
	my $peer = $this->{'peers'}->{$fileno};
	
	close($peer->socket());
	delete  $this->{'peers'}->{$fileno};
	# peer and address should already be untainted
	my $filename = Digest::SHA::sha256_hex($peer->address.':'.$peer->port);
	my $path_active = $this->db_path().'/peers/active/'.$filename;
	my $path_banned = $this->db_path().'/peers/banned/'.$filename;
	
	if($path_active =~ m/^(.*)$/){
		$path_active = $1;
	}
	if($path_banned =~ m/^(.*)$/){
		$path_banned = $1;
	}
	
	rename($path_active,$path_banned);
	
	delete $this->{'peers by address:port'}->{$peer->address}->{$peer->port};
	delete $this->{'peers by address:port'}->{$peer->address};
	
	
	$logger->debug("Peer of ".$peer->address." and ".$peer->port." with filename=$filename has been closed and deleted.");
}


=pod

---+ Brain

Here, these subroutines figure out what data we need to get from peers based on our current state.

=cut

=pod

---++ peer_hook_handshake_finished($peer)

This is called when a handshake is finished.

=cut

sub peer_hook_handshake_finished{
	my ($this,$peer) = @_;
	
	$logger->debug("Running send getblocks since hand shake is finished");
	#$peer->send_getheaders();
	#$peer->send_getaddr();
	if($this->block_height() < $peer->block_height()){
		$logger->debug("alpha; block height diff=".( $peer->block_height() - $this->block_height() ));
		#$peer->send_getblocks();
		$peer->send_getheaders();
	}
	else{
		$logger->debug("beta; block height diff=".( $peer->block_height() - $this->block_height() ));
		$peer->send_getaddr();
	}
	
	if($this->peer_pool_count() < 30){
		$peer->send_getaddr();
	}
	
	#$peer->send_getblocks();
}




=pod

---++ hook_inv($type,$hash)

Add the pair to the list of inventory_vectors that need to be fetched

0 	ERROR 	Any data of with this number may be ignored
1 	MSG_TX 	Hash is related to a transaction
2 	MSG_BLOCK 	Hash is related to a data block
3 	MSG_FILTERED_BLOCK 	Hash of a block header; identical to MSG_BLOCK. When used in a getdata message, this

=cut

=pod

---+++ Data Structure
 
The following means that no getdata has been sent:
$this->{'inv search'}->{$type}->{$hash} = [0]

$this->{'inv search'}->{$type}->{$hash} = [timesent?,result?]

When done, set result=1???

=cut

sub hook_inv {
	my ($this,$peer,$type,$hash) = @_;
	#
	
	
	return undef unless defined $type && (0 <= $type && $type <= 3 ) &&
		 defined $hash && 0 < length($hash);
	# length($hash) should be equal to 32 (256bits), but in the future that might change.
	
	if($type == 2){
		# block
		return undef if $this->{'header by hash'}->{$hash};
		
		$this->{'command timeout'}->{'send_getblocks'} = 0;
		
	}
	
	#my $pchain = $peer->chain();
	
	#warn "Got inv [$type;".unpack('H*',$hash)."]\n";
	unless(defined $this->{'inv search'}->[$type]->{$hash}){
		$this->{'inv search'}->[$type]->{$hash} = [0,$peer];
		push(@{$this->{'inv next getdata'}->[$type]},$hash);
	}
	
	# what do we do?
	# nothing, everything gets handled in Peer::callback_gotinv
	
	
}

=pod

---++ hook_peer_onreadidle($peer)

A peer can do a read, so, after reading in the bytes, figure out what to do.

=cut

sub hook_peer_onreadidle {
	my ($this,$peer) = @_;
	return undef unless $peer->handshake_finished();
#	$this->sort_chain();
	# check to see if we need to fetch more inv
	#warn "check to see if we need to fetch more inv with p=".$this->hook_getdata_blocks_preview()."\n";
	#$peer->send_getdata($this->hook_getdata());
	
	# we might have to wait for a ping before this request goes out to the peer
	#if($this->is_marked_getblocks() && 60 < time() - $this->{'getblocks timeout'} ){
		#warn "getting blocks\n";
	#	$peer->send_getblocks();
	#	$this->is_marked_getblocks(0);
	#	$this->{'getblocks timeout'} = time();
	#}
	
	$this->activate_peer();
	
	
	#warn "Peer=".$peer->address().";Num of Headers=".scalar(@{$this->{'headers'}})."\n";
	$logger->debug("Peer=".$peer->address().";Num of Headers=".scalar(@{$this->{'headers'}}));
	
	if(0 < $this->hook_getdata_blocks_preview()){
		#warn "Need to fetch more inv\n";
		$logger->debug("Neet to fetch more inv");
		$peer->send_getdata($this->hook_getdata());
	}
	else{
		#warn "\n";
		$logger->debug("Need to fetch more blocks");
		if($this->block_height() < $peer->block_height()){
			#warn ."\n";
			$logger->debug("alpha; block height diff=".( $peer->block_height() - $this->block_height() ));
			#$peer->send_getblocks();
			$peer->send_getheaders();
			# if the speed is less than 10B/second, then give this to another peer
			# ..

			
			#print "Bail out!";
			#exit 0;
		}
		else{
			#warn "we are caught up with peer=$peer";
			$logger->debug("we are caught up with peer=$peer");
			#$peer->send_getaddr();
		}
		
		if($this->peer_pool_count() < 20){
			$peer->send_getaddr();
		}
	}

}

=pod

---++ hook_getdata($peer,$max)

This is called by a peer when it is ready to write.  Max count= 100 per peer rather than 500 in order to encourage the spreading of the getdata burden to more peers.  The timeout is 60 seconds.

=cut

sub hook_getdata {
	my ($this,$max_count) = @_;
	my @response;
	
	$max_count = 500 unless defined $max_count;
	#$max_count = 4;
	
	my $gd_timeout = 600;
	
	my ($i,$max_count_per_peer) = (0,$max_count);
	#warn "hook_getdata part 1 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[0]}){
		# error
		if(
			$i < $max_count_per_peer 
			&& $gd_timeout < (time() - $this->{'inv search'}->[0]->{$hash}->[0] )
		){
			push(@response,pack('L',0).$hash);
			$this->{'inv search'}->[0]->{$hash}->[0] = time();
			$i += 1;
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 2 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[1]}){
		# tx
		if(
			$i < $max_count_per_peer 
			&& $gd_timeout < (time() - $this->{'inv search'}->[1]->{$hash}->[0] )
		){
			push(@response,pack('L',1).$hash);
			$this->{'inv search'}->[1]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 3 \n";
	while(my $hash = shift(@{$this->{'inv next getdata'}->[2]})  ){
		# block
		if(
			$i < $max_count_per_peer 
			&& $gd_timeout < (time() - $this->{'inv search'}->[2]->{$hash}->[0] )
		){
			push(@response,pack('L',2).$hash);
			$this->{'inv search'}->[2]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			unshift(@{$this->{'inv next getdata'}->[2]},$hash);
			last;
		}
	}
	#$this->{'inv next getdata'}->[2] = [];
	
	#warn "hook_getdata part 4 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[3]}){
		# filtered block
		if(
			$i < $max_count_per_peer 
			&& $gd_timeout < (time() - $this->{'inv search'}->[3]->{$hash}->[0] )
		){
			push(@response,pack('L',3).$hash);
			$this->{'inv search'}->[3]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata size is ".scalar(@response)."\n";
	
	
	if(0 < scalar(@response)){
		return CBitcoin::Utilities::serialize_varint(scalar(@response)).join('',@response);
	}
	else{
	# do a check to see if we need to fetch more blocks
		# hook_getdata
		# $this->spv->{'inv search'}->[2]
		#warn "need to do another block fetch...";

		
		# when a peer is not busy, the first peer to see this will fetch a block
		$this->is_marked_getblocks(1);
		
		
		return '';	
	}
	 

	
}

=pod

---+++ hook_getdata_blocks_size

Includes stuff that is waiting on time out.

=cut

sub hook_getdata_blocks_size {
	my $this = shift;
	return (keys %{$this->{'inv search'}->[2]});
}

=pod

---+++ hook_getdata_blocks_preview

Does not include stuff that is waiting on time out.

Use this to figure out if we have retrieved all inventory vectors.

=cut

sub hook_getdata_blocks_preview {
	my ($this,$max_count_per_peer) = @_;
	#warn "hook_getdata part 2 \n";
	my $i = 0;
	foreach my $hash (keys %{$this->{'inv search'}->[2]}){
		# tx
		if( 
			60 < (time() - $this->{'inv search'}->[2]->{$hash}->[0] )
		){
			#push(@response,pack('L',1).$hash);
			#$this->{'inv search'}->[1]->{$hash}->[0] = time();
			$i += 1;	
		}
		#elsif($max_count_per_peer < $i){
		#	last;
		#}
	}
	return $i;
}

=pod

---+ Event Loop

=cut

=pod

---++ loop($loopsub, $connectsub)

Run an infinite loop

=cut

sub loop {
	my ($this) = @_;
	
	my ($loopsub,$connectsub) = (
		$this->event_loop->loop(),$this->event_loop->connect()
	);

	
	warn "Starting loop\n";
	$loopsub->($this,$connectsub);
}


=pod

---+ Command and Control

=cut

=pod

---++ cnc_receive_message($target,$msg)

Receive a message via one of the cnc mqueues.  The $mark_off_sub turns off the callback if there is nothing to write.

Check DefaultEventLoop module to see how this subroutine gets called.

=cut

sub cnc_receive_message {
	my ($this,$target,$msg_data) = @_;
	open(my $fh,'<',\$msg_data);
	my $msg;
	eval{
		$msg = CBitcoin::Message->deserialize($fh);
	} || do{
		my $error = $@;
		$logger->error("Got error=$error");
		return undef;
	};
	
	# TODO: limit what messages can be received on cnc
	
	if($target eq 'cnc in' || $target eq 'cnc own'){
		# got a command
		my $command = $msg->command();
		$logger->debug("Got command=$command");
		my $sub;
		if(
			defined $callback_mapper->{'command'}->{$command}
			&& defined $callback_mapper->{'command'}->{$command}->{'subroutine'}
			&& ref($callback_mapper->{'command'}->{$command}->{'subroutine'}) eq 'CODE'
		){
			$sub = $callback_mapper->{'command'}->{$command}->{'subroutine'};
		}
		elsif(
			defined $callback_mapper->{'custom command'}->{$command}
			&& defined $callback_mapper->{'custom command'}->{$command}->{'subroutine'}
			&& ref($callback_mapper->{'custom command'}->{$command}->{'subroutine'}) eq 'CODE'
		){
			$sub = $callback_mapper->{'custom command'}->{$command}->{'subroutine'};
			$logger->error( "custom command=$command");
		}
		else{
			$sub = sub{
				my $cmd = \$command;
				$logger->debug("Got incorrect command=".$$cmd);
			};
		}
		# my ($this,$msg,$peer) = @_;
		# but there is no peer
		$sub->($this,$msg,undef);
		
	}
	else{
		$logger->error("Got weird message from $target");
	}
}

=pod

---++ cnc_send_message_data($target,$mark_off_sub)

Send a message via one of the cnc mqueues.  The $mark_off_sub turns off the callback if there is nothing to write.

Check DefaultEventLoop module to see how this subroutine gets called.

Do not use this subroutine to send messages out from the spv.  Use cnc_send_message for that purpose.

=cut

sub cnc_send_message_data {
	my ($this,$target,$mark_off_sub) = @_;
	
	# check the queue for $target
	$this->{'cnc queues'}->{$target} = [] unless defined $this->{'cnc queues'}->{$target};
	my $num = scalar(@{$this->{'cnc queues'}->{$target}});
	if($num == 0){
		$this->{'cnc callbacks'}->{$target}->{'mark write'} = $mark_off_sub->();
		return undef;
	}
	else{
		#$logger->debug("pid=$target sending data");
		return shift(@{$this->{'cnc queues'}->{$target}});
	}
}



=pod

---++ cnc_send_message($target,$data)

Put some data on the write queue.

Check DefaultEventLoop module to see how this subroutine gets called.

TODO: the mqueue sockets get drowned out by the tcp sockets.  Need away to send multiple mqueue messages in one shot.


=cut

sub cnc_send_message {
	my ($this,$target,$data) = @_;
	$this->{'cnc queues'}->{$target} = [] unless defined $this->{'cnc queues'}->{$target};
	push(@{$this->{'cnc queues'}->{$target}},$data);
	
	if(defined $this->{'cnc callbacks'}->{$target}->{'mark write'}){
		$this->{'cnc callbacks'}->{$target}->{'mark write'}->();
		delete $this->{'cnc callbacks'}->{$target}->{'mark write'};
	}
	#$logger->debug("$target queue size is ".scalar(@{$this->{'cnc queues'}->{$target}}));
	return scalar(@{$this->{'cnc queues'}->{$target}});
}


=pod

---++ cnc_broadcast_message($data)

Send data to all other spv processes.

=cut

sub cnc_broadcast_message {
	my ($this,$data) = @_;
	$logger->debug("doing cnc broadcast");
	foreach my $pid (keys %{$this->{'cnc queues'}}){
		$logger->debug("Got pid=$pid and our pid=".$$);
		next unless $pid =~ m/^(\d+)$/ && $pid != $$;
		$logger->debug("broadcast to pid=$pid ");
		$this->cnc_send_message($pid,$data);
	}

}


=pod

---++ cncout_send_header($block)

Send a header out.

=cut

sub cncout_send_header{
	my ($this,$block) = @_;
	
	
	#$logger->debug("data=".unpack('H*',$data));
	$this->cnc_send_message('cnc out',
		CBitcoin::Message::serialize($block->header().pack('C',0),'block',$CBitcoin::network_bytes)
	);
}

=pod

---++ cncout_send_status()

Send a status update out.

=cut

sub cncout_send_status {
	my ($this) = @_;
	
	$this->cnc_send_message('cnc out',
		CBitcoin::Message::serialize(JSON::encode_json({ 'time' => time() }),'custom_json',$CBitcoin::network_bytes)
	);

}


=pod

---+ Broadasting Messages

The logic used to figure out what needs to be uploaded and downloaded is stored here.

=cut

=pod

---++ broadcast_message(@msgs)

Send a message out to the bitcoin network via all peers.

=cut

sub broadcast_message {
	my $this = shift;
	
	foreach my $msg (@_){
		foreach my $fileno (keys %{$this->{'peers'}}){
			$this->{'peers'}->{$fileno}->write($msg);
		}
	}
}





=pod

---+ Callbacks

When a message is recieved, the command is parsed from the message and used to fetch the subroutine, which is stored in the global hash $callback_mapper.

=cut

=pod

---++ callback_add($peer,$callback,$timeout)->$nonce

Add a custom callback where the args are ($delete_sub,$peer,$message)

The callbacks are run after the default callbacks, not before.  

=cut

sub callback_add {
	my ($this,$peer,$callback,$timeout) = @_;
	$timeout = 2*time() unless defined $timeout;
	
	unless(defined $callback && ref($callback) eq 'CODE'){
#		$logger->error("Callback is not an a subroutine");
		return undef;
	}
	
	
	$peer = 'any peer' unless defined $peer;
	
	my $nonce = $this->{'callbacks nonce'};
	$this->{'callbacks nonce'} += 1;
	
	my $deletesub = sub{
		my ($t1,$p1,$n1) = ($this,$peer,$nonce);
		delete $t1->{'callbacks'}->{$p1}->{$n1};
	};
	
	$this->{'callbacks'}->{$peer}->{$nonce} = [$timeout,$callback,$deletesub];

	return $nonce;
}


=pod

---++ get_callback_mapper

Overload this if you want to run a different set of callbacks than default.

=cut

sub get_callback_mapper {
	return 	$callback_mapper;
}

=pod

---++ callback_run

When a receiving a message from a peer, handle it.  Callback subroutines must accept @args = ($spv,$msg,$peer).

=cut


sub callback_run {
	my ($this,$msg,$peer) = @_;

	return undef unless defined $peer && defined $msg;
	
	# handle default callbacks
	my $command = $msg->command();
	my $cm = $this->get_callback_mapper();
	if(
		defined $cm->{'command'}->{$command}
		&& ref($cm->{'command'}->{$command}) eq 'HASH'
		&& defined $cm->{'command'}->{$command}->{'subroutine'}
		&& ref($cm->{'command'}->{$command}->{'subroutine'}) eq 'CODE'
	){
		# run the default callback
		$logger->debug("Running callback with command=$command");
		$cm->{'command'}->{$command}->{'subroutine'}->($this,$msg,$peer);
	}

	# handle custom callbacks

	my @x = ('any peer');
	if(
		defined $this->{'callbacks'}->{$peer}
		&& ref($this->{'callbacks'}->{$peer}) eq 'HASH'
		&& 0 < scalar(keys %{$this->{'callbacks'}->{$peer}})
	){
		push(@x,$peer);
	}

	foreach my $py (@x){
		
		foreach my $nonce (keys %{$this->{'callbacks'}->{$py}}){
			# [$timeout,$callback,$deletesub]
			if(
				time() - $this->{'callbacks'}->{$py}->{$nonce}->[0] < 0
			){
				# spv,deletesub,peer,msg
				$this->{'callbacks'}->{$py}->{$nonce}->[1]->(
					$this,
					$this->{'callbacks'}->{$py}->{$nonce}->[2],
					$peer,
					$msg
				);				
			}
			else{
				# exceeded timeout, delete callback
				$this->{'callbacks'}->{$py}->{$nonce}->[2]->();
			}

		}
	}

	return undef;
}


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
	my ($this,$msg,$peer) = @_;
	return undef;
	#warn "gotaddr\n";
	open(my $fh,'<',\$msg->{'payload'});
	my $addr_ref = CBitcoin::Utilities::deserialize_addr($fh);
	close($fh);
	if(defined $addr_ref && ref($addr_ref) eq 'ARRAY'){
		#warn "Got ".scalar(@{$addr_ref})." new addresses\n";
		
		foreach my $addr (@{$addr_ref}){
			# timestamp, services, ipaddress, port
			$this->add_peer_to_inmemmory(
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
	my ($this,$msg,$peer) = @_;
	
	# handshake should not be finished
	if($peer->handshake_finished()){
		#warn "peer already finished handshake, but received another version\n";
		$peer->mark_finished();
		return undef;
	}
	
	# we should not already have a version
	if($peer->received_version()){
		#warn "peer already sent a version\n";
		$peer->mark_finished();
		return undef;
	}


	# parse version	
	unless($peer->version_deserialize($msg)){
		#warn "peer sent bad version\n";
		$peer->mark_finished();
		return undef;
	}
	
	
	#open(my)
	$peer->{'received version'} = 1;
	
	$peer->send_verack();
	return 1;
}


=pod

---++ callback_gotverack

Used in the handshake.

=cut

sub callback_gotverack {
	my ($this,$msg,$peer) = @_;
	
	
	# we should not have already received a verack
	if($peer->received_verack()){
		#warn "bad peer, already received verack";
		$peer->mark_finished();
		return undef;
	}
	
	# we should have sent a version
	if(!$peer->sent_version()){
		#warn "no version sent, so we should not be getting a verack\n";
		$peer->mark_finished();
		return undef;
	}
	
	$peer->{'received verack'} = 1;
	
	$peer->send_ping();
	return 1;
}

=pod

---++ callback_ping

Used after a timeout has been reached, to confirm that the connection is still up.

=cut

sub callback_gotping {
	my ($this,$msg,$peer) = @_;
	warn "Got ping\n";
	unless($peer->handshake_finished()){
		#warn "got ping before handshek finsihed\n";
		$peer->mark_finished();
		return undef;
	}
	$peer->send_pong($msg->payload());
	return 1;
}

=pod

---++ callback_pong

Sent by a peer in response to a ping sent by us.

=cut

sub callback_gotpong {
	my ($this,$msg,$peer) = @_;
	
	if($peer->{'sent ping nonce'} eq $msg->payload() ){
		warn "got pong and it matches";
		$peer->{'sent ping nonce'} = undef;
		$peer->{'last pinged'} = time();
		return 1;
	}
	else{
		#warn "bad pong received\n";
		$peer->mark_finished();
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
	my ($this,$msg,$peer) = @_;
	#warn "Got inv\n";
	unless($peer->handshake_finished()){
		#warn "got inv before handshake finsihed\n";
		$peer->mark_finished();
		return undef;
	}
	open(my $fh,'<',\($msg->payload()));
	binmode($fh);
	my $count = CBitcoin::Utilities::deserialize_varint($fh);
	#warn "gotinv: count=$count\n";
	for(my $i=0;$i < $count;$i++){
		# in hook_inv, mark send_blocks clean
		$this->hook_inv($peer,@{CBitcoin::Utilities::deserialize_inv($fh)});
	}
	close($fh);
	
	# go fetch the data
	$peer->send_getdata($this->hook_getdata());
	
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
	my ($this,$msg,$peer) = @_;
	
	# deserialize_filter for when you have a wallet
	my $block = CBitcoin::Block->deserialize_filtered($msg->payload(),$this->bloom_filter());
	#my $block = CBitcoin::Block->deserialize($msg->payload());
	
	return undef unless $block->{'success'};
	
	# TODO: Fix the faulty prevBlockHash (returning bogus hash....)
	
	$logger->debug("Got block=[".$block->hash_hex().
		";".$block->transactionNum.
		";".length($msg->payload())."]");
	#warn "Cummulative Difficulty:".$peer->chain()->{'cummulative difficulty'}->as_hex()."\n";
	my $count = $block->transactionNum;
		#die "let us finish early\n";
		
	
	
	#delete $this->{'inv search'}->[2]->{$block->hash()};
	if(
		defined  $this->{'inv search'}->[2]->{$block->hash()}->[1]
		&& $this->{'inv search'}->[2]->{$block->hash()}->[1] ne $peer
	){
		my $peer_original = $this->{'inv search'}->[2]->{$block->hash()}->[1];
		
		$this->add_header_to_chain($peer_original,$block);		
		
	}
	else{
		#warn "missing inv with hash=".$block->hash_hex()."\n";
		$this->add_header_to_chain($peer,$block);
	}
	delete $this->{'inv search'}->[2]->{$block->hash()};



	if($block->transactionNum_bf()){
		$this->callback_gotblock_withtx($block);
	}
	
	
	$this->hook_peer_onreadidle($peer);
	

	
	
	#$this->spv->{'inv'}->[2]->{$block->hash()} = $block;
#	unlink($fp) if -f $fp;
}


=pod

---++ callback_gotblock_withtx

For when we have a block that has transactions of interest.  Overload this subroutine in order to do accounting for balances.

=cut

sub callback_gotblock_withtx{
	my ($this,$block) = @_;
	
	$logger->debug("Got Block with transaction");
}

=pod

---++ callback_gottx

Got tx that has not been confirmed.

=cut

sub callback_gottx{
	my ($this,$tx) = @_;
	
	$logger->debug("Got TX");
	
	#my $header = $block->header();
	#open(my $fh,'>','/tmp/spv/'.$block->hash_hex);
	#my ($m) = (0);
	#while(0 < length($header) - $m){
#		$m += syswrite($fh,$header,8192,$m);
#	}
#	close($fh);
}


=pod

---++ callback_gotheaders

Got headers, so put them into the database.

=cut

BEGIN{
	$callback_mapper->{'command'}->{'headers'} = {
		'subroutine' => \&callback_gotheaders
	}
};

sub callback_gotheaders {
	my ($this,$msg,$peer) = @_;
	my $payload = $msg->payload();
	open(my $fh,'<',\$payload);
	
	my $num_of_headers = CBitcoin::Utilities::deserialize_varint($fh);
	$logger->debug("number of headers=$num_of_headers");
	return undef unless 0 < $num_of_headers;
	my $x = CBitcoin::Utilities::serialize_varint($num_of_headers);
	$x = length($x);
	
	
	for(my $i=0;$i<$num_of_headers;$i++){
		my $block = CBitcoin::Block->deserialize(substr($payload, $x+ 81*$i, 81));
		if(!$block->success()){
			$logger->debug("got bad header");
			next;
		}
		
		#$logger->debug("($i/$num_of_headers)Got header=[".$block->hash_hex().
		#	";".$block->transactionNum.
		#	";".length($msg->payload())."]");
			
		$this->add_header_to_chain($peer,$block);
		
		#delete $this->{'inv search'}->[2]->{$block->hash()};
		if(defined  $this->{'inv search'}->[2]->{$block->hash()}){
			$logger->debug("deleting inv with hash=".$block->hash_hex());
			delete $this->{'inv search'}->[2]->{$block->hash()};# = undef;
		}
		else{
			#$logger->debug("missing inv with hash=".$block->hash_hex());
		}
		
	}
	
	$this->hook_peer_onreadidle($peer);
}

=pod

---+ custom callbacks

=cut

=pod

---++ callback_gotaddspv

Store the new addr in the peer database.

=cut

BEGIN{
	$callback_mapper->{'custom command'}->{'custaddspv'} = {
		'subroutine' => \&callback_custom_gotaddspv
	}
};

sub callback_custom_gotaddspv {
	my ($this,$msg) = @_;
	
	# check for new spv
	foreach my $pid (@{$this->event_loop->cncspv_add($this)}){
		$logger->debug("Adding spv pid=$pid");
		$this->{'cnc queues'}->{$pid} = [];
	}	
}



1;