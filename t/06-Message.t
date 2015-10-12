use 5.014002;
use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::SPV;
use IO::Socket::INET;
$| = 1;

#use Test::More tests => 1;


my $spv = CBitcoin::SPV->new({
	'address' => '192.168.122.67',
	'port' => 8333,
	'isLocal' => 1
	
});



my $socket = new IO::Socket::INET (
	PeerHost => '10.19.202.164',
	#PeerHost => '10.27.18.198',
	PeerPort => '8333',
	Proto => 'tcp',
) or die "ERROR in Socket Creation : $!\n";

my @conn = ('10.19.202.164','8333');

$spv->add_peer($socket,@conn);



############################# EPoll stuff for quick testing ########################

use IO::Epoll;

my $epfd = epoll_create(10);

epoll_ctl($epfd, EPOLL_CTL_ADD, fileno($spv->peer(@conn)->socket()), EPOLLIN | EPOLLOUT ) >= 0 || die "epoll_ctl: $!\n";


while(my $events = epoll_wait($epfd, 10, -1)){
	foreach my $event (@{$events}){
		my $n = 0;
		if($event->[1] & EPOLLIN){
			# time to read
			$spv->peer(@conn)->read_data();
		}
		if($event->[1] & EPOLLOUT ){
			$spv->peer(@conn)->write_data();
		}
	}
}



#ok(1) || print "Bail out!";
