package CBitcoin::SPV;

use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::Utilities;
use CBitcoin::Peer;
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
	bless($this,$package);
	
	$this->{'db path'} = '/tmp/spv';
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
	
	
}

=pod

---+ Getters/Setters

=cut

sub db_path {
	return shift->{'db path'};
}

sub peers_path {
	return shift->{'db path'}.'/peers';
}

sub max_connections {
	return shift->{'max connections'};
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
	my ($socket, $addr_recv_ip,$addr_recv_port) = (shift,shift,shift);
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
			rename($dir_pool.'/'.$latest,$dir_pending.'/'.$latest) || die "alpha";
			
			# create connection
			open($fh,'<',$dir_pending.'/'.$latest) || die "beta";
			my @guts = <$fh>;
			close($fh);
			
			die "charlie" unless scalar(@guts) == 3;
			
			# connect with ip address and port
			# the connection logic is not here, that is left to the final program to decide
			# perhaps the end user wants to use tor, or a proxy to connect
			# so, let that logic be elsewhere, just send an anonymous subroutine
			$socket = $connect_sub->($this,$guts[1],$guts[2]);
			unless(defined $socket && fileno($socket) > 0){
				rename($dir_pending.'/'.$latest,$dir_banned.'/'.$latest);
				die "delta";
			}
			
			# we have a socket, ready to go
			$this->add_peer($socket,$guts[1],$guts[2]);
			
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

---+ Brain

Here, these subroutines figure out what data we need to get from peers based on our current state.

=cut





1;