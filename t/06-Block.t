use strict;
use warnings;


#use CBitcoin::Block;
require Data::Dumper;
use Test::More tests => 3;

use CBitcoin::Message;
use CBitcoin::Block;

#my $gen_block = CBitcoin::Block->genesis_block();
#warn "Hash=".$gen_block->hash_hex."\n";
#warn "prevBlockHash=".$gen_block->prevBlockHash_hex."\n";
#warn "Data=".unpack('H*',$gen_block->data)."\n";

open(my $fh,'<','t/blk0.ser') || print "Bail out!";
binmode($fh);

my $msg = CBitcoin::Message->deserialize($fh);
close($fh);

my $block = CBitcoin::Block->deserialize($msg->payload() );

#warn "XO=".$block->hash_hex."\n";
ok( $block->{'success'}, 'Genesis Block' );
my $gen_hash = $block->hash() if $block->{'success'};
#warn "XO=[".unpack('H*',$msg->payload())."]\n";

open($fh,'<','t/blk120383.ser') || print "Bail out!";
binmode($fh);
$msg = CBitcoin::Message->deserialize($fh);
close($fh);

$block = CBitcoin::Block->deserialize($msg->payload() );
#warn "XO=".$block->hash_hex."\n";

ok( $block->{'success'}, 'Big Block' );


$block = CBitcoin::Block->genesis_block();
ok( $block->{'success'} && $block->hash() eq $gen_hash, 'Genesis Block sub' );

#my $newblock = block_BlockFromData(,0);





__END__

use CBitcoin::Message;
use CBitcoin::SPV;
use IO::Socket::INET;
use IO::Epoll;
$| = 1;





my $epfd = epoll_create(10);



# set umask so that files/directories will be 0700 or 0600

umask(077);
`mv /tmp/spv/active/* /tmp/spv/pool/`;





my $connectsub = sub{
	my ($this,$ipaddress,$port) = @_;
	my $sck1;
	my $epfd_inside = $epfd;
	warn "Doing connection now, part 1\n";
	eval{
		$sck1 = new IO::Socket::INET (
			PeerHost => $ipaddress,
			PeerPort => $port,
			Proto => 'tcp',
		) or die "ERROR in Socket Creation : $!\n";
		warn "Doing connection now, part 2\n";
		epoll_ctl($epfd_inside, EPOLL_CTL_ADD, fileno($sck1), EPOLLIN | EPOLLOUT ) >= 0 || die "epoll_ctl: $!\n";
	};
	my $error = $@;
	if($error){
		warn "bad connection, error=$error";
		return undef;
	}
	else{
		warn "Doing connection now, part 3\n";
		return $sck1;
	}
};


my $spv = CBitcoin::SPV->new({
	'address' => '192.168.122.67',
	'port' => 8333,
	'isLocal' => 1
});


#my $socket = new IO::Socket::INET (
#	PeerHost => '10.19.202.164',
#	#PeerHost => '10.27.18.198',
#	PeerPort => '8333',
#	Proto => 'tcp',
#) or die "ERROR in Socket Creation : $!\n";

my @conn = ('10.19.202.164','8333');




$spv->add_peer_to_db(pack('Q',1),@conn);
$spv->activate_peer($connectsub);


#$spv->add_peer($socket,@conn);





############################# EPoll stuff for quick testing ########################


while(my $events = epoll_wait($epfd, 10, -1)){
	foreach my $event (@{$events}){
		#warn "sockets match" if fileno($socket) eq $event->[0];
		warn "Top of epoll loop\n";
		$spv->activate_peer($connectsub);
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
			if(defined $spv->peer_by_fileno($event->[0])$spv->peer_by_fileno($event->[0])->write() > 0){
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

#ok(1) || print "Bail out!";
