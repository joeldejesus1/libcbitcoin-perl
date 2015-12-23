use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::SPV;
use IO::Socket::INET;
use IO::Epoll;
$| = 1;





my $epfd = epoll_create(100);



# set umask so that files/directories will be 0700 or 0600

umask(077);
`mv /tmp/spv/active/* /tmp/spv/pool/`;



my $connectsub = sub{
	my ($this,$ipaddress,$port) = @_;
	my $sck1;
	my $epfd_inside = $epfd;
	warn "Doing connection now, part 1\n";
	eval{
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm 5;
		$sck1 = new IO::Socket::INET (
			PeerHost => $ipaddress,
			PeerPort => $port,
			Proto => 'tcp',
		) or die "ERROR in Socket Creation : $!\n";
		alarm 0;
		warn "Doing connection now, part 2\n";
		epoll_ctl($epfd_inside, EPOLL_CTL_ADD, fileno($sck1), EPOLLIN | EPOLLOUT ) >= 0 || die "epoll_ctl: $!\n";
	};
	my $error = $@;
	if($error){
		alarm 0;
		warn "bad connection, error=$error";
		return undef;
	}
	else{
		warn "Doing connection now, part 3\n";
		return $sck1;
	}
};

my $markwritesub = sub{
	my ($sck1) = (shift);
	my $epfd_inside = $epfd;
	epoll_ctl($epfd_inside, EPOLL_CTL_MOD, fileno($sck1), EPOLLIN | EPOLLOUT ) >= 0 || die "epoll_ctl: $!\n";
};


my $spv = CBitcoin::SPV->new({
	'address' => '192.168.122.67',
	'port' => 8333,
	'isLocal' => 1,
	'connect sub' => $connectsub,
	'mark write sub' => $markwritesub 
});


#my $socket = new IO::Socket::INET (
#	PeerHost => '10.19.202.164',
#	#PeerHost => '10.27.18.198',
#	PeerPort => '8333',
#	Proto => 'tcp',
#) or die "ERROR in Socket Creation : $!\n";

my @conn = ('10.19.202.164','8333');


foreach my $node ('10.19.202.164','69.164.218.197','46.214.15.40','89.69.168.15','218.161.44.5'){
	$spv->add_peer_to_db(pack('Q',1),$node,'8333');		
}


$spv->activate_peer($connectsub);


#$spv->add_peer($socket,@conn);





############################# EPoll stuff for quick testing ########################


while(my $events = epoll_wait($epfd, 10, -1)){
	warn "Top of epoll loop\n";
	$spv->activate_peer($connectsub);
	
	foreach my $event (@{$events}){
		#warn "sockets match" if fileno($socket) eq $event->[0];
		
		
		if($event->[1] & EPOLLIN){
			# time to read
			$spv->peer_by_fileno($event->[0])->read_data();
			
			# socket may have been closed on attempted read, so check if the peer is still defined
			if(defined $spv->peer_by_fileno($event->[0]) && $spv->peer_by_fileno($event->[0])->write() > 0){
				warn "setting eventmask to read/write\n";
				epoll_ctl($epfd, EPOLL_CTL_MOD, $event->[0], EPOLLIN | EPOLLOUT ) >= 0 || die "epoll_ctl: $!\n";
			}
		}
		# the connection may have been cut during the read section, so check if the $peer is still around
		if(defined $spv->peer_by_fileno($event->[0]) && $event->[1] & EPOLLOUT ){
			if(defined $spv->peer_by_fileno($event->[0]) && $spv->peer_by_fileno($event->[0])->write() > 0){
				$spv->peer_by_fileno($event->[0])->write_data();
			}
			else{
				warn "setting eventmask to just read\n";
				epoll_ctl($epfd, EPOLL_CTL_MOD, $event->[0], EPOLLIN ) >= 0 || die "epoll_ctl: $!\n";
			}
			
		}
	}
	last if scalar(keys %{$spv->{'peers'}}) == 0;
}

warn "no more connections, add peers and try again\n";
