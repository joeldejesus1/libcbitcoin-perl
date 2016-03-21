package CBitcoin::SPV;

use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::Utilities;
use CBitcoin::Peer;
use CBitcoin::Block;
use Net::IP;


=pod

---+ new({'})

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
	
	unless(defined $this->{'latest block'}){
		$this->{'latest block'} = [-1,-1];
	}

#	my @path = CBitcoin::Utilities::HashToFilepath($block->hash_hex);
	my $base = $this->db_path();
	my $headersfp = "$base/headers";
	
	warn "link blocks\n";
	my ($buf);
	opendir(my $fh,$headersfp) || return;
	my @x1 = readdir($fh);
	closedir($fh);
	foreach my $y1 (@x1){
		next if $y1 eq '.' || $y1 eq '..';
		opendir($fh,$headersfp.'/'.$y1);
		my @x2 = readdir($fh);
		closedir($fh);
		foreach my $y2 (@x2){
			next if $y2 eq '.' || $y2 eq '..';
			opendir($fh,$headersfp.'/'.$y1.'/'.$y2);
			my @x3 = readdir($fh);
			close($fh);
			foreach my $y3 (@x3){
				next if $y3 eq '.' || $y3 eq '..';
				# finally got to block directories
				my $blockfp = $headersfp.'/'.$y1.'/'.$y2.'/'.$y3;
				next if defined $this->{'blocks'}->{pack('H*',$y1.$y2.$y3)};
				
				# get the previousHash
				open(my $fhin,'<',$headersfp.'/'.$y1.'/'.$y2.'/'.$y3.'/prevBlockHash') || die "cannot read hash";
				my $prevhash;
				while(sysread($fhin,$buf,8192)){ $prevhash .= $buf; }
				close($fhin);
				#warn "PrevHash:".unpack('H*',$prevhash)." with length ".length($prevhash)."\n";
				my $hash = pack('H*',$y1.$y2.$y3);
				# [$prevhash,$index_num,$nexthash]
				$this->{'blocks'}->{$hash} = [$prevhash,-1,-1];
				if(defined $this->{'blocks'}->{$prevhash}){
					$this->{'blocks'}->{$prevhash}->[2] = $hash;
					
					if(0 < $this->{'blocks'}->{$prevhash}->[1]){
						$this->{'blocks'}->{$hash}->[1] = $this->{'blocks'}->{$prevhash}->[1] + 1;
						$this->{'block index'}->[$this->{'blocks'}->{$hash}->[1]] = $hash;
						# set the latest block to [$index,$hash]
						$this->{'latest block'} = [$this->{'blocks'}->{$hash}->[1],$hash]
							if $this->{'latest block'} < $this->{'blocks'}->{$hash}->[1];
					}
				
				}
				elsif(unpack('H*',$prevhash) eq '0000000000000000000000000000000000000000000000000000000000000000'){
					
					# this is the genesis block
					$this->{'blocks'}->{$hash}->[1] = 0;
					$this->{'block index'}->[$this->{'blocks'}->{$hash}->[1]] = $hash;
				}
			}
		}
	}
	
	#require Data::Dumper;
	#my $xo = Data::Dumper::Dumper($this->{'blocks'});
	#warn "XO=$xo\n";
	
	
	# do one more loop to make sure links work
	foreach my $h1 (keys %{$this->{'blocks'}}){
		# prevhash   $this->{'blocks'}->{$h1}->[0]
		# index      $this->{'blocks'}->{$h1}->[1]
		# nexthash   $this->{'blocks'}->{$h1}->[2]

		# set nexthash in previous block
		if(
			defined $h1 && length($h1) == 32
			&& defined $this->{'blocks'}->{$h1}->[0] && length($this->{'blocks'}->{$h1}->[0]) == 32
			&& defined $this->{'blocks'}->{$this->{'blocks'}->{$h1}->[0]}->[2]
			&& length($this->{'blocks'}->{$this->{'blocks'}->{$h1}->[0]}->[2]) == 32
		){
			$this->{'blocks'}->{$this->{'blocks'}->{$h1}->[0]}->[2] = $h1
		}

		
	}
	
	my $index = 0;
	my ($ch);
	#CBitcoin::Block->genesis_block();
	$ch = $this->{'block index'}->[$index];
	#$next_hash = $this->{'blocks'}->{$current_hash}->[2];
	die "genesis block hash not defined" unless defined $ch;
	while(1){
		$index += 1;
		$ch = $this->{'blocks'}->{$ch}->[2];
		last if !(defined $ch) || length($ch) != 32;
		$this->{'block index'}->[$index] = $ch;
		$this->{'latest block'} = [$index,$ch];
	}
	
	#require Data::Dumper;
	#$xo = Data::Dumper::Dumper($this->{'block index'});
	#warn "XO=$xo\n";
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

=pod

---+++ block($index)

Get block by index number.

=cut

sub block_height {
	my $this = shift;
	
	#return $this->{'latest block'}->[0];
	
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

---+++ count_blocks()

Go through the file system and map out the index.

=cut

sub count_blocks {
	my $this = shift;


	
=pod
	my $fh;
	
	my @path = CBitcoin::Utilities::HashToFilepath($block->hash_hex);
	unless(-d "$base/headers/".join('/',@path)){
		CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path,'tx'));	
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
=cut
}

=pod

---+++ add_block_to_db($block)

Store block header.

=cut

sub add_block_to_db{
	my ($this,$block) = (shift,shift);
	return undef unless defined $block && ref($block) eq 'CBitcoin::Block';

	# store the block on disk
	#$this->add_header_to_chain($block);
	my @path = CBitcoin::Utilities::HashToFilepath($block->hash_hex);
	my $base = $this->db_path();
	my $fh;
	
	my @path = CBitcoin::Utilities::HashToFilepath($block->hash_hex);
	unless(-d "$base/headers/".join('/',@path)){
		CBitcoin::Utilities::recursive_mkdir("$base/headers/".join('/',@path,'tx'));	
		my $n;
		open($fh,'>',"$base/headers/".join('/',@path).'/prevBlockHash') || die "cannot save prevblock hash";
		$n = syswrite($fh,$block->prevBlockHash);
		die "could not save hash" unless $n == length($block->prevBlockHash) && $n > 1;
		close($fh);
		open($fh,'>',"$base/headers/".join('/',@path).'/data') || die "cannot save block data";
		$n = syswrite($fh,$block->data);
		die "could not save data" unless $n == length($block->data) && $n > 1;
		close($fh);
		
		#open($fh,'>',"$base/headers/".join('/',@path).'/hash') || die "cannot save block hash";
		#$n = syswrite($fh,$block->hash);
		#die "could not save hash" unless $n == length($block->hash) && $n > 1;
		#close($fh);
	}
	#$this->count_blocks();
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
	
	
	
	my ($latest,$socket);
	#warn "activating peer - 3\n";
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
			warn "part 3 with socket=".fileno($socket)."\n";
			
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
	#warn "Adding peer to db\n";
	
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
		warn "adding peer offering full blocks, not just headers\n";
		print $fh "FULLBLOCKS\n";
	}
	else{
		warn "adding peer offering just headers\n";
		print $fh "HEADERSONLY\n";		
	}
	#warn "adding peer 4\n";
	print $fh "$addr_recv_ip\n$addr_recv_port\n";
	close($fh);
	#warn "adding peer 5\n";
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
	#warn "peer_by_fileno=$fileno\n with glob=".ref($this->{'peers'}->{$fileno})."\n";
	
	require Data::Dumper;
	my $xo = Data::Dumper::Dumper($this->{'peers'});
	open(my $fhout,'>','/tmp/bonus2');
	print "peer_by_fileno\n";
	print $fhout $xo;
	close($fhout);
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
	
	warn "Ready to go! with $peer\n";
	#$this->hook_getdata();
	$peer->write($peer->hook_getblocks());
}

=pod

---++ getdata($type,$hash)

Add the pair to the list of inventory_vectors that need to be fetched

=cut

sub getdata {
	my $this = shift;
	my ($type,$hash) = @_;
	
	my $typemapper = ['error','tx','block','filtered_block'];
	
	# type is a number
	my $typeENG = $typemapper->[$type];
	
	return undef unless defined $typeENG && ($typeENG eq 'error' || $typeENG eq 'tx' || $typeENG eq 'block' ) && defined $hash && length($hash) == 32;
	
	# length($hash) should be equal to 32 (256bits), but in the future that might change.
	warn "Adding inv($type,".unpack('H*',$hash).")\n";
	
	unless(defined $this->{'inv queue'}){
		$this->{'inv queue'} = [];
	}
	
	unless(defined $this->{'inv search'}->{$type}->{$hash}){
		# mark when the inv was added
		$this->{'inv search'}->{$type}->{$hash} = [time()];
		push(@{$this->{'inv queue'}},[$type,$hash]);
	}
}

=pod

---++ hook_getdata($peer)

This is called by a peer when it is ready to write.  Max count= 500 per peer.  The timeout is 60 seconds.

This subroutine is called in Peer::read_data via Peer::spv_hook_getdata

=cut

sub hook_getdata {
	my $this = shift;
	my $peer = shift;
	
	my @response;
	warn "hook_getdata part 1\n";
	return undef unless defined $this->{'inv queue'} && ref($this->{'inv queue'}) eq 'ARRAY' && 0 < scalar(@{$this->{'inv queue'}});
	
	warn "hook_getdata part 2\n";
	my $n = 0;
	my @response;
	while(0 < scalar(@{$this->{'inv queue'}}) && $n < 500){
		my $invref  = shift(@{$this->{'inv queue'}});
		$n += 1;
		# mark when the getdata is going out 
		$this->{'inv search'}->{$invref->[0]}->{$invref->[1]}->[1] = time();
		# mark which peer is fetching this vector
		$this->{'inv search'}->{$invref->[0]}->{$invref->[1]}->[2] = $peer;
		push(@response,$invref);	
	}
	
	$peer->send_getdata(\@response);

	return 1; # return number of items sent
	
=pod
	my ($i,$max_count_per_peer) = (0,500);
	warn "hook_getdata part 1 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'error'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'error'}->{$hash}->[0] )){
			push(@response,pack('L',0).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	warn "hook_getdata part 2 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'tx'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'tx'}->{$hash}->[0] )){
			push(@response,pack('L',1).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	warn "hook_getdata part 3 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'block'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'block'}->{$hash}->[0] )){
			push(@response,pack('L',2).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	warn "hook_getdata part 4 \n";
	foreach my $hash (keys %{$this->{'inv search'}->{'filtered block'}}){
		if($i < $max_count_per_peer && 60 < (time() - $this->{'inv search'}->{'filtered block'}->{$hash}->[0] )){
			push(@response,pack('L',3).$hash);
			$i += 1;	
		}
		elsif($max_count_per_peer < $i){
			last;
		}
	}
	warn "hook_getdata size is ".scalar(@response)."\n";
	return CBitcoin::Utilities::serialize_varint(scalar(@response)).join('',@response) if scalar(@response) > 0;
=cut
	return '';
}


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