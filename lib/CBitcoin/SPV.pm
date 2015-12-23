package CBitcoin::SPV;

use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::Utilities;
use CBitcoin::Peer;
use CBitcoin::Block;
use Net::IP;


=pod

---+ new

Create a new SPV client.


=cut

sub new {
	my $package = shift;
	my $options = shift;
	$options ||= {};
	#my $this = CBitcoin::Message::spv_initialize(ip_convert_to_binary('0.0.0.0'),0);
	my $this = $options;
	
	die "no mark write sub" unless defined $this->{'mark write sub'} && ref($this->{'mark write sub'}) eq 'CODE';
	die "no connect sub" unless defined $this->{'connect sub'} && ref($this->{'connect sub'}) eq 'CODE';
	
	bless($this,$package);
	
	$this->{'version'} = 70001 unless defined $this->{'version'};
	
	$this->{'db path'} = '/tmp/spv' unless defined $this->{'db path'};
	$this->make_directories();

	
	# config settings
	
	# ..max connections
	if(defined $this->{'max connections'} && $this->{'max connections'} =~ m/^(\d+)$/){
		$this->{'max connections'} = $1;
	}
	elsif(!defined $this->{'max connections'}){
		$this->{'max connections'} = 8;
	}
	else{
		die "bad max connection setting";
	}
	
	# start block chain at 0
	$this->{'headers'} = [];
	$this->{'transactions'} = {};
	$this->initialize_chain();
	
	
	# brain
	$this->{'inv'} = {
		'error' => {},
		'tx' => {},
		'block' => {},
		'filtered block' => {}
	};
	$this->{'inv search'} = {
		'error' => {},
		'tx' => {},
		'block' => {},
		'filtered block' => {} 
	};
	
	return $this;
	
}


sub make_directories{
	my $this = shift;
	my $base = $this->{'db path'};
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

---++ initialize_chain

Save the genesis block into block headers.  Also, create the first block locator for use in getheaders.

=cut

sub initialize_chain{
	my $this = shift;
	my $base = $this->db_path();
	warn "initialize chain 1\n";
	opendir(my $fh, $base.'/headers') || die "cannot open directory to headers";
	warn "initialize chain 1.2\n";
	my @files = grep { $_ ne '.' && $_ ne '..' } readdir $fh;
	warn "initialize chain 1.3\n";
	closedir($fh);
	unless(0 == scalar(@files)){
		#die "no files?=".scalar(@files)."\n";
		return $this->initialize_chain_scan_files();	
	}
	warn "initialize chain 2\n";
	# must get genesis block
	my $gen_block = CBitcoin::Block->genesis_block();
	warn "Genesis hash=".$gen_block->hash_hex."\n";
	warn "Genesis prevBlockHash=".$gen_block->prevBlockHash_hex."\n";

	my @path = CBitcoin::Utilities::HashToFilepath($gen_block->hash_hex);
	warn "initialize chain 3\n";
	CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path)) 
		unless -d "$base/headers/".join('/',@path);
	my $n;
	open($fh,'>',"$base/headers/".join('/',@path).'/prevBlockHash') || die "cannot save prevblock hash";
	$n = syswrite($fh,$gen_block->prevBlockHash);
	die "could not save hash" unless $n == length($gen_block->prevBlockHash) && $n > 1;
	close($fh);
	warn "initialize chain 4\n";
	open($fh,'>',"$base/headers/".join('/',@path).'/data') || die "cannot save block data";
	$n = syswrite($fh,$gen_block->data);
	die "could not save data" unless $n == length($gen_block->data) && $n > 1;
	close($fh);
	
	warn "initialize chain 5 hash=".unpack('H*',$gen_block->hash)."\n";
	#$this->{'headers'}->[0] = $gen_block->hash;
	push(@{$this->{'headers'}},$gen_block->hash);
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'headers'});
	#warn "XO1=$xo\n"; 
	
	$this->block_height(0);
	
	
	return 1;
}

sub initialize_chain_scan_files {
	my $this = shift;
}

=pod

---++ add_header_to_chain($block)

=cut

sub add_header_to_chain {
	my $this = shift;
	my $block = shift;
	die "block is null" unless defined $block;
	
	my $base = $this->db_path();
	my $fh;
	
	my @path = CBitcoin::Utilities::HashToFilepath($block->hash_hex);
	unless(-d "$base/headers/".join('/',@path)){
		CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path));	
		my $n;
		open($fh,'>',"$base/headers/".join('/',@path).'/prevBlockHash') || die "cannot save prevblock hash";
		$n = syswrite($fh,$block->prevBlockHash);
		die "could not save hash" unless $n == length($block->prevBlockHash) && $n > 1;
		close($fh);
		open($fh,'>',"$base/headers/".join('/',@path).'/data') || die "cannot save block data";
		$n = syswrite($fh,$block->data);
		die "could not save data" unless $n == length($block->data) && $n > 1;
		close($fh);
	}
	push(@{$this->{'headers'}},$block->hash);
	return $this->block_height(1);
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
		my $hash = $this->block($i);
		die "bad index, rebuild block header database" unless defined $hash;
		push(@ans,$hash);
	}
	warn "Have index of n=".scalar(@ans)."\n";
	# pack('L',$this->version) 
#	if(scalar(@ans) == 1){
#		# need to download whole chain
#		#push(@ans,pack('H*','5c3e6403d40837110a2e8afb602b1c01714bda7ce23bea0a0000000000000000'));
#		push(@ans,pack('H*','6c3e6403d40837110a2e8afb602b1c01714bda7ce23bea0a0000000000000000'));
#	}
	
	
	return pack('L',$this->version).CBitcoin::Utilities::serialize_varint(scalar(@ans)).join('',@ans).$hash_stop;
}


=pod

---+ Getters/Setters

=cut

sub db_path {
	return shift->{'db path'};
}

sub version {
	return shift->{'version'};
}

sub peers_path {
	return shift->{'db path'}.'/peers';
}

sub max_connections {
	return shift->{'max connections'};
}

sub mark_write {
	my $this = shift;
	my $socket = shift;
	warn "doing mark write\n";
	return $this->{'mark write sub'}->($socket);
}



sub block{
	my ($this,$index) = (shift,shift);
	die "bad index given" unless
		$index =~ m/^(\d+)$/ && 0 <= $index;
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'headers'});
	#warn "XO=$xo\n"; 
	warn "Returning block i=$index v=".unpack('H*',$this->{'headers'}->[$index])."\n";
	return $this->{'headers'}->[$index];
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

=pod

---+ Networking

=cut


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

---++ add_peer($socket,$addr_recv_ip,$addr_recv_port)

Mark that a peer has been connected to and that it is ready to do a handshake.


=cut

sub add_peer{
	my $this = shift;
	
	my ($socket, $addr_recv_ip,$addr_recv_port) = (shift,shift,shift,shift);
	my $ref = $this->our_address();
	my $peer = CBitcoin::Peer->new({
		'spv' => $this,
		'socket' => $socket,
		'address' => $addr_recv_ip, 'port' => $addr_recv_port,
		'our address' => $ref->[0], 'our port' => $ref->[1]
	});
	# go by fileno, it is friendly to IO::Epoll
	$this->{'peers'}->{fileno($socket)} = $peer;
	$this->{'peers by address:port'}->{$addr_recv_ip}->{$addr_recv_port} = $peer;
	
	
	
	
	return 1;
}

=pod

---++ add_peer_obj($peer)

Same as add_peer, but feed in a Peer object.

=cut

sub add_peer_obj{
	my ($this,$peer) = (shift,shift);
	
	$this->{'peers'}->{fileno($peer->socket)} = $peer;
	$this->{'peers by address:port'}->{$peer->address}->{$peer->port} = $peer;
	
	return 1;
}



=pod

---++ activate_peer()

Find a peer in a pool, and turn it on

=cut

sub activate_peer {
	my $this = shift;
	my $connect_sub = shift;
	# if we are maxed out on connections, then exit
	return undef unless scalar(keys %{$this->{'peers'}}) < $this->max_connections();
	
	die "not given connection sub" unless defined $connect_sub && ref($connect_sub) eq 'CODE';
	

	my $dir_pool = $this->db_path().'/peers/pool';
	my $dir_active = $this->db_path().'/peers/active';
	my $dir_pending = $this->db_path().'/peers/pending';
	my $dir_banned = $this->db_path().'/peers/banned';
	
	opendir(my $fh,$dir_pool) || die "cannot open directory";
	my @files = grep { $_ ne '.' && $_ ne '..' } readdir $fh;
	closedir($fh);
	
	my @peer_files = sort @files;
	
	
	
	my ($latest,$socket);

	while(scalar(@peer_files)>0){
		$latest = shift(@peer_files);
		warn "Latest peer to try to connect to is hash=$latest\n";
		# untaint
		if("$latest" =~ m/^(.*)$/){
			$latest = $1;
		}
		
		
		eval{
			warn "part 1\n";
			rename($dir_pool.'/'.$latest,$dir_pending.'/'.$latest) || die "alpha";
			
			# create connection
			open($fh,'<',$dir_pending.'/'.$latest) || die "beta";
			my @guts = <$fh>;
			close($fh);
			warn "part 2\n";
			die "charlie" unless scalar(@guts) == 3;
			
			# connect with ip address and port
			# the connection logic is not here, that is left to the final program to decide
			# perhaps the end user wants to use tor, or a proxy to connect
			# so, let that logic be elsewhere, just send an anonymous subroutine
			$socket = $connect_sub->($this,$guts[1],$guts[2]);
			warn "part 3\n";
			unless(defined $socket && fileno($socket) > 0){
				rename($dir_pending.'/'.$latest,$dir_banned.'/'.$latest);
				die "delta";
			}
			
			# we have a socket, ready to go
			$this->add_peer($socket,$guts[1],$guts[2]);
			warn "part 4\n";
			rename($dir_pending.'/'.$latest,$dir_active.'/'.$latest);
			
		};
		my $error = $@;
		if($error){
			warn "have to try another peer. Error=$error\n";
		}
		else{
			warn "finished looping to find a new peer\n";
			last;
		}

	}

	
}

=pod

---++ add_peer_to_db($services,$addr_recv_ip,$addr_recv_port)

This adds a peer to a list of potential peers, but does not create a new connection.

File:
HEADERSONLY
ipaddrss
port

=cut

sub add_peer_to_db{
	
	my ($this,$services, $addr_recv_ip,$addr_recv_port) = (shift,shift,shift,shift);
	warn "Adding peer to db\n";
	
	my $filename = Digest::SHA::sha256_hex("$addr_recv_ip:$addr_recv_port");
	warn "Filepath =".$this->db_path().'/peers/pool/'.$filename."\n";
	
	return undef if -f $this->db_path().'/peers/pool/'.$filename || -f $this->db_path().'/peers/active/'.$filename 
		|| -f $this->db_path().'/peers/banned/'.$filename;
	
	warn "adding peer 2\n";
	my $fh;
	#if($this->db_path().'/peers/pool/'.$filename =~ m/^(.*)$/){
		
	#}
	open($fh, '>',$this->db_path().'/peers/pool/'.$filename) || die "cannot open file for peer\n";
	warn "adding peer 3\n";
	if($services & pack('Q',1)){
		warn "adding peer offering full blocks, not just headers\n";
		print $fh "FULLBLOCKS\n";
	}
	else{
		warn "adding peer offering just headers\n";
		print $fh "HEADERSONLY\n";		
	}
	warn "adding peer 4\n";
	print $fh "$addr_recv_ip\n$addr_recv_port\n";
	close($fh);
	warn "adding peer 5\n";
	return 1;
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
	return $this->{'peers'}->{$fileno};
}

=pod

---++ close_peer($fileno_of_socket)

=cut

sub close_peer {
	my $this = shift;
	my $fileno = shift;
	
	my $peer = $this->{'peers'}->{$fileno};
	
	close($peer->socket());
	delete  $this->{'peers'}->{$fileno};
	
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
	
}

=pod

---++ getdata($type,$hash)

Add the pair to the list of inventory_vectors that need to be fetched

=cut

sub getdata {
	my $this = shift;
	my ($type,$hash) = @_;
	return undef unless defined $type && ($type eq 'error' || $type eq 'tx' || $type eq 'block' ) && defined $hash && length($hash) > 0;
	# length($hash) should be equal to 32 (256bits), but in the future that might change.
	
	unless(defined $this->{'inv search'}->{$type}->{$hash}){
		$this->{'inv search'}->{$type}->{$hash} = [0];
	}
}

=pod

---++ hook_getdata()

This is called by a peer when it is ready to write.  Max count= 500 per peer.  The timeout is 60 seconds.

=cut

sub hook_getdata {
	my $this = shift;
	my @response;
	
	my ($i,$max_count_per_peer) = (0,500);
	#warn "hook_getdata part 1 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'error'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'error'}->{$hash}->[0] )){
			push(@response,pack('L',0).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 2 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'tx'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'tx'}->{$hash}->[0] )){
			push(@response,pack('L',1).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 3 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'block'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'block'}->{$hash}->[0] )){
			push(@response,pack('L',2).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata part 4 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'filtered block'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'filtered block'}->{$hash}->[0] )){
			push(@response,pack('L',3).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	#warn "hook_getdata size is ".scalar(@response)."\n";
	return CBitcoin::Utilities::serialize_varint(scalar(@response)).join('',@response) if scalar(@response) > 0;
	return '';
}



1;