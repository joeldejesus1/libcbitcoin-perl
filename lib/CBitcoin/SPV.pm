package CBitcoin::SPV;

use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::Utilities;
use CBitcoin::Peer;
use CBitcoin::Block;
use Net::IP;


=pod

---+ contructors/destructors

=cut


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
	$this = $this->init($options);
	bless($this,$package);
	
	$this->make_directories();
	
	# start block chain at 0
	$this->{'headers'} = [];
	$this->{'transactions'} = {};
	$this->initialize_chain();
	$this->sort_chain();
	
	# brain
	$this->{'inv'} = [{},{},{},{}];
	$this->{'inv search'} = [{},{},{},{}];	
	$this->initialize_peers();

	return $this;
	
}

=pod

---++ init($options)

Overload this subroutine.

=cut

sub init {
	my ($this,$options) = @_;
	
	die "no mark write sub" unless defined $options->{'mark write sub'} 
		&& ref($options->{'mark write sub'}) eq 'CODE';
	die "no connect sub" unless defined $options->{'connect sub'} 
		&& ref($options->{'connect sub'}) eq 'CODE';
	
	
	
	$options->{'version'} = 70001 unless defined $options->{'version'};
	
	$options->{'db path'} = '/tmp/spv' unless defined $options->{'db path'};
	

	$options->{'last getaddr'} = 0;
	
	# config settings
	
	# ..max connections
	if(defined $options->{'max connections'} && $options->{'max connections'} =~ m/^(\d+)$/){
		$options->{'max connections'} = $1;
	}
	elsif(!defined $options->{'max connections'}){
		$options->{'max connections'} = 8;
	}
	else{
		die "bad max connection setting";
	}
	
	return $options;
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
		next if $f1 eq '.' || $f1 eq '..';
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
	#warn "initialize chain 1\n";
	opendir(my $fh, $base.'/headers') || die "cannot open directory to headers at ". $base.'/headers';
	#warn "initialize chain 1.2\n";
	my @files = grep { $_ ne '.' && $_ ne '..' } readdir $fh;
	#warn "initialize chain 1.3\n";
	closedir($fh);
	unless(0 == scalar(@files)){
		#die "no files?=".scalar(@files)."\n";
		return $this->initialize_chain_scan_files(\@files);	
	}
	#warn "initialize chain 2\n";
	# must get genesis block
	my $gen_block = CBitcoin::Block->genesis_block();
	#warn "Genesis hash=".$gen_block->hash_hex."\n";
	#warn "Genesis prevBlockHash=".$gen_block->prevBlockHash_hex."\n";

	my @path = CBitcoin::Utilities::HashToFilepath($gen_block->hash_hex);
	
	#warn "initialize chain 3\n";
	CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path)) 
		unless -d "$base/headers/".join('/',@path);
	my $n;
	open($fh,'>',"$base/headers/".join('/',@path).'/prevBlockHash') 
		|| die "cannot save prevblock hash";
	$n = syswrite($fh,$gen_block->prevBlockHash);
	die "could not save hash" unless $n == length($gen_block->prevBlockHash) && $n > 1;
	close($fh);
	
	#warn "initialize chain 4\n";
	open($fh,'>',"$base/headers/".join('/',@path).'/data') || die "cannot save block data";
	my $data = $gen_block->serialize_header();
	$n = syswrite($fh,$data);
	die "could not save data" unless $n == length($data) && $n > 1;
	close($fh);
	
	#warn "initialize chain 5 hash=".unpack('H*',$gen_block->hash)."\n";
	#$this->{'headers'}->[0] = $gen_block->hash;
	$this->add_header_to_chain($gen_block);
	#push(@{$this->{'headers'}},$gen_block->hash);
	
	return 1;
}

=pod

---++ initialize_chain_scan_files(\@files)

Given a set of files, scan in blocks.

Make sure the hash/directory relationship matches that in CBitcoin::Utilities::HashToFilepath.

=cut

sub initialize_chain_scan_files {
	my ($this,$files_ref) = @_;
	
	my $base = $this->db_path();
	
	#my $gen_block = CBitcoin::Block->genesis_block();
	
	# get all the hashes
	# format=1,3,the rest
	foreach my $f1 (@{$files_ref}){
		opendir(my $fh2,"$base/headers/$f1") || die "cannot open directory";
		while(my $f2 = readdir($fh2)) {
		 	next if $f2 eq '.' || $f2 eq '..';
		 	#warn "in directory=$base/headers/$f1/$f2\n";
		 	opendir(my $fh3,"$base/headers/$f1/$f2") || die "cannot open directory";
		 	while(my $f3 = readdir($fh3)){
		 		next if $f3 eq '.' || $f3 eq '..';
		 		open(my $fhdata,'<',"$base/headers/$f1/$f2/$f3") || die "cannot read data";
		 		$this->add_header_to_inmemory_chain(CBitcoin::Block->deserialize($fhdata));
		 		close($fhdata);
		 	}
		 	closedir($fh3);
		}
		closedir($fh2);
	}
	
	$this->sort_chain();
}

=pod

---++ add_header_to_chain($block)

Directory: $dbpath/headers/hash1/hash2/hash3/

In the directory:
	./prevBlockHash (binary format)
	./data (serialized header with tx count set to 0)
	
=cut

sub add_header_to_chain {
	my $this = shift;
	my $header = shift;
	die "header is null" unless defined $header;
	
	my $base = $this->db_path();
	my ($fh,$n);
	
	# the size is 3, with 2 directories and the final element being the file name
	my @path = CBitcoin::Utilities::HashToFilepath($header->hash_hex);
	die "path is not the right size" unless scalar(@path) == 3;

	unless(-d "$base/headers/".join('/',@path)){
		# the dir is the hex of the hash
		CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path[0..1]));
		
		# write the header into ./data
		open($fh,'>',"$base/headers/".join('/',@path)) || die "cannot save block data";
		my $data = $header->serialize_header();
		$n = 0;
		while(0 < length($data) - $n){
			$n += syswrite($fh,$data, 8192, $n);
		}
		close($fh);
		
		$this->add_header_to_db($header);
	}
	$this->add_header_to_inmemory_chain($header);
	#return $this->block_height(1);
}

=pod

---++ add_header_to_inmemory_chain

=cut

sub add_header_to_inmemory_chain {
	my ($this,$header) = @_;
	
	if(defined $this->{'header hash to hash'}->{$header->hash} ){
		$this->{'header hash to hash'}->{$header->hash}->[0] = $header->prevBlockHash;
	}
	else{
		$this->{'header hash to hash'}->{$header->hash} = [$header->prevBlockHash,''];
	}
	
	if(defined $this->{'header hash to hash'}->{$header->prevBlockHash}){
		$this->{'header hash to hash'}->{$header->prevBlockHash}->[1] = $header->hash;
	}
	else{
		$this->{'header hash to hash'}->{$header->prevBlockHash} = ['',$header->hash];
	}
	
	$this->{'header changed'} = 1;
}

=pod

---++ sort_chain

=cut

sub sort_chain {
	my ($this) = @_;
	
	return undef unless $this->{'header changed'};
	
	$this->{'headers'} = [];
	
	my $mainref = $this->{'header hash to hash'};
	my $gen_block = CBitcoin::Block->genesis_block();
	my $curr_hash = $gen_block->hash;
	my $loopcheck = {};
	while(defined $curr_hash && $curr_hash ne '' && !($loopcheck->{$curr_hash})){
		#warn "New hash=".unpack('H*',$curr_hash)."\n";
		push(@{$this->{'headers'}},$curr_hash);
		$loopcheck->{$curr_hash} = 1;
		$curr_hash = $mainref->{$curr_hash}->[1];
		
	}
	#warn "finished sorting, new block_height=".scalar(@{$this->{'headers'}})."\n";
	$this->{'header changed'} = 0;
}

=pod

---++ calculate_block_locator($hash_stop)

Go through the in-memory chain, and create the block_locator hash array.  Return a serialized message.

=cut

sub calculate_block_locator {
	my $this = shift;
	my $hash_stop = shift;
	
	# 32 bytes of null
	unless(defined $hash_stop){
		$hash_stop = pack('x');
		foreach my $i (2..32){
			$hash_stop .= pack('x');
		}
	}
	
	#$hash_stop = pack('H*','0000000000000000000000000000000000000000000000000000000000000000') unless defined $hash_stop;
	
	my @ans;
	foreach my $i (CBitcoin::Utilities::block_locator_indicies($this->block_height())){
		#warn "need block=$i\n";
		my $hash = $this->block($i);
		die "bad index, rebuild block header database" unless defined $hash;
		push(@ans,$hash);
	}
	#warn "Have index of n=".scalar(@ans)."\n";
	# pack('L',$this->version) 
#	if(scalar(@ans) == 1){
#		# need to download whole chain
#		#push(@ans,pack('H*','5c3e6403d40837110a2e8afb602b1c01714bda7ce23bea0a0000000000000000'));
#		push(@ans,pack('H*','6c3e6403d40837110a2e8afb602b1c01714bda7ce23bea0a0000000000000000'));
#	}
	
	
	return pack('L',$this->version).CBitcoin::Utilities::serialize_varint(scalar(@ans)).
		join('',@ans).$hash_stop;
}

=pod

---+ database

=cut

=pod

---++ add_header_to_db($header)

=cut

sub add_header_to_db {
	my ($this, $header) = @_;
	
	warn "New header with hash=".unpack('H*',$header->hash)."\n";
}

=pod

---++ add_tx_to_db($block_hash,$tx)

Given a block hash and a transaction, do something.

=cut

sub add_tx_to_db {
	my ($this,$block_hash,$tx) = @_;

	warn "Tx with inputs=".scalar(@{$tx->{'inputs'}})." and outputs=".
		scalar(@{$tx->{'outputs'}})."\n";
}

=pod

---++ add_peer_to_db($peer)

=cut

sub add_peer_to_db {
	my ($this,$peer) = @_;
	
	warn "Got Peer in database\n";
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
	
	if($this->{'header changed'}){
		$this->sort_chain();
	}
	
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
	my $this = shift;
	return scalar(@{$this->{'headers'}}) - 1;
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

---++ activate_peer()

Find a peer in a pool, and turn it on

=cut

sub activate_peer {
	my $this = shift;
	my $connect_sub = $this->{'connect sub'};
	#warn "activating peer - 1\n";
	# if we are maxed out on connections, then exit
	return undef unless scalar(keys %{$this->{'peers'}}) < $this->max_connections();
	#warn "activating peer - 1.1\n";
	die "not given connection sub" unless defined $connect_sub && ref($connect_sub) eq 'CODE';
	#warn "activating peer - 2\n";

	my $dir_pool = $this->db_path().'/peers/pool';
	my $dir_active = $this->db_path().'/peers/active';
	my $dir_pending = $this->db_path().'/peers/pending';
	my $dir_banned = $this->db_path().'/peers/banned';
	#warn "activating peer - 2\n";
	opendir(my $fh,$dir_pool) || die "cannot open directory";
	my @files = grep { $_ ne '.' && $_ ne '..' } readdir $fh;
	closedir($fh);
	
	my @peer_files = sort @files;
	
	my $numOfpeers = scalar(@peer_files);
	
	#warn "have num of peers =$numOfpeers\n";
	
	
	
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
	}
	
	
	my ($latest,$socket);
	#warn "activating peer - 3\n";
	while(scalar(@peer_files)>0){
		$latest = shift(@peer_files);
		#warn "Latest peer to try to connect to is hash=$latest\n";
		# untaint
		if("$latest" =~ m/^(.*)$/){
			$latest = $1;
		}
		
		
		eval{
			#warn "part 1\n";
			rename($dir_pool.'/'.$latest,$dir_pending.'/'.$latest) || die "alpha";
			
			# create connection
			open($fh,'<',$dir_pending.'/'.$latest) || die "beta";
			my @guts = <$fh>;
			close($fh);
			#warn "part 2\n";
			die "charlie" unless scalar(@guts) == 3;
			
			# connect with ip address and port
			# the connection logic is not here, that is left to the final program to decide
			# perhaps the end user wants to use tor, or a proxy to connect
			# so, let that logic be elsewhere, just send an anonymous subroutine
			$socket = $connect_sub->($this,$guts[1],$guts[2]);
			#warn "part 3 with socket=".fileno($socket)."\n";
			
			unless(defined $socket && fileno($socket) > 0){
				rename($dir_pending.'/'.$latest,$dir_banned.'/'.$latest);
				die "delta";
			}
			
			# we have a socket, ready to go
			$this->add_peer($socket,$guts[1],$guts[2]);
			#warn "part 4\n";
			rename($dir_pending.'/'.$latest,$dir_active.'/'.$latest);
			
		};
		my $error = $@;
		if($error){
			warn "have to try another peer. Error=$error\n";
		}
		else{
			#warn "finished looping to find a new peer\n";
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
	my $peer = CBitcoin::Peer->new({
		'spv' => $this,
		'socket' => $socket,
		'address' => $addr_recv_ip, 'port' => $addr_recv_port,
		'our address' => $ref->[0], 'our port' => $ref->[1]
	});
	# basically, this gets overloaded by an inheriting class
	$this->add_peer_to_db($peer);

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
	return '';
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
	
	# TODO: untaint everything!
	
	my $peer = $this->{'peers'}->{$fileno};
	
	close($peer->socket());
	delete  $this->{'peers'}->{$fileno};
	# peer and address should already be untainted
	my $filename = Digest::SHA::sha256_hex($peer->address.':'.$peer->port);
	my $path_active = $this->db_path().'/peers/active/'.$filename;
	my $path_banned = $this->db_path().'/peers/banned/'.$filename;
	rename($path_active,$path_banned);
	
	delete $this->{'peers by address:port'}->{$peer->address}->{$peer->port};
	delete $this->{'peers by address:port'}->{$peer->address};
	
	
	
	warn "Peer of ".$peer->address." and ".$peer->port." with filename=$filename has been closed and deleted.\n";
}


=pod

---+ Brain

Here, these subroutines figure out what data we need to get from peers based on our current state.

=cut

=pod


---++ peer_hook_handshake_finished()

This is called when a handshake is finished.

=cut

sub peer_hook_handshake_finished{
	my $this = shift;
	my $peer = shift;
	#warn "Running send getblocks since hand shake is finished\n";
	
	#$peer->send_getheaders();
	$peer->send_getaddr();
	
	$peer->send_getblocks();
}

=pod

---++ hook_inv($type,$hash)

Add the pair to the list of inventory_vectors that need to be fetched

0 	ERROR 	Any data of with this number may be ignored
1 	MSG_TX 	Hash is related to a transaction
2 	MSG_BLOCK 	Hash is related to a data block
3 	MSG_FILTERED_BLOCK 	Hash of a block header; identical to MSG_BLOCK. When used in a getdata message, this

---+++ Data Structure
 
The following means that no getdata has been sent:
$this->{'inv search'}->{$type}->{$hash} = [0]

$this->{'inv search'}->{$type}->{$hash} = [timesent?,result?]

When done, set result=1???

=cut

sub hook_inv {
	my ($this,$type,$hash) = @_;
	warn "Got inv of type=$type with hash=".unpack('H*',$hash)."\n";
	
	return undef unless defined $type && (0 <= $type && $type <= 3 ) &&
		 defined $hash && length($hash) > 0;
	# length($hash) should be equal to 32 (256bits), but in the future that might change.
	
	
	unless(defined $this->{'inv search'}->[$type]->{$hash}){
		$this->{'inv search'}->[$type]->{$hash} = [0];
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
	
	# check to see if we need to fetch more inv
	#warn "check to see if we need to fetch more inv\n";
	$peer->send_getdata($this->hook_getdata());
	
	# we might have to wait for a ping before this request goes out to the peer
	if($this->is_marked_getblocks()){
		#warn "getting blocks\n";
		$peer->send_getblocks();
		$this->is_marked_getblocks(0);
	}
}

=pod

---++ hook_getdata($peer)

This is called by a peer when it is ready to write.  Max count= 500 per peer.  The timeout is 60 seconds.

=cut

sub hook_getdata {
	my $this = shift;
	my @response;
	
	my ($i,$max_count_per_peer) = (0,500);
	#warn "hook_getdata part 1 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[0]}){
		# error
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->[0]->{$hash}->[0] )){
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
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->[1]->{$hash}->[0] )){
			push(@response,pack('L',1).$hash);
			$this->{'inv search'}->[1]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 3 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[2]}){
		# block
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->[2]->{$hash}->[0] )){
			push(@response,pack('L',2).$hash);
			$this->{'inv search'}->[2]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 4 \n";
	foreach my $hash (keys %{$this->{'inv search'}->[3]}){
		# filtered block
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->[3]->{$hash}->[0] )){
			push(@response,pack('L',3).$hash);
			$this->{'inv search'}->[3]->{$hash}->[0] = time();
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	warn "hook_getdata size is ".scalar(@response)."\n";
	
	
	if(0 < scalar(@response)){
		return CBitcoin::Utilities::serialize_varint(scalar(@response)).join('',@response);
	}
	else{
	# do a check to see if we need to fetch more blocks
		# hook_getdata
		# $this->spv->{'inv search'}->[2]
		#warn "need to do another block fetch...";
		$this->sort_chain();
		
		# when a peer is not busy, the first peer to see this will fetch a block
		$this->is_marked_getblocks(1);
		
		
		return '';	
	}
	 

	
}

=pod

---+ Event Loop

=cut

=pod

---++ loop($loopsub, $connectsub)

Run an infinite loop

=cut

sub loop {
	my ($this,$loopsub,$connectsub) = (shift,shift,shift);
	die "no loop sub" unless defined $loopsub && ref($loopsub) eq 'CODE';
	die "no connect sub" unless defined $connectsub && ref($connectsub) eq 'CODE';
	$loopsub->($this,$connectsub);
}



1;