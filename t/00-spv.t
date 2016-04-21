use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::SPV;
use IO::Socket::INET;
use IO::Epoll;
use EV;

$| = 1;

use Test::More tests => 1;

my $gen_block = CBitcoin::Block->genesis_block();
warn "Hash=".$gen_block->hash_hex."\n";
warn "prevBlockHash=".$gen_block->prevBlockHash_hex."\n";
warn "Data=".unpack('H*',$gen_block->data)."\n";
ok(1) || print "Bail out!";

# set umask so that files/directories will be 0700 or 0600

umask(077);
#`mv /tmp/spv/active/* /tmp/spv/pool/`;

# we need to define a connectsub, markwritesub, loopsub.


my $fn_to_watcher = {};

my $config = {
	'timeout' => 15
};


my $mode = 0;
my $mode_setting = sub{
	my $x = shift;
	my $m1 = \$mode;
	if(defined $x && $x == 0){
		# waiting for pong
		${$m1} = 0; 
	}
	elsif(defined $x){
		# time to send ping
		${$m1} = 1;
	}
	else{
		return ${$m1};
	}
};


# $resettimeout->($spv,$socket)
my $resettimeout = sub{
	my ($spv,$sck1) = @_;
	my $internal_fn_watcher = $fn_to_watcher;
	my $c1 = $config;
	

	$mode_setting->(1);
	
	# callback sub
	my $cbhash = {'x' => 1};
	$cbhash->{'x'} = sub {
		warn "is called after ".$config->{'timeout'}."s";
		
		my $c2 = $c1;
		my $spv_in = $spv;
		my $sck2 = $sck1;	
		my $ms = $mode_setting;
		my $ifw = $internal_fn_watcher;
		my $cbh = $cbhash;
		my $cb2 = $cbh->{'x'};
		$spv_in->activate_peer();
		if($ms->()){
			# 1 first time out, send ping
			$ms->(0);
			$spv_in->peer_by_fileno(fileno($sck2))->send_ping();
			delete $ifw->{fileno($sck2).'timer'};
			$ifw->{fileno($sck2).'timer'} = EV::timer 30, 0, $cb2;
		}
		else{
			warn "connection timed out\n";
			$spv_in->close_peer(fileno($sck2));
			
		}
		
		
	};
	my $callback = $cbhash->{'x'};
	delete $internal_fn_watcher->{fileno($sck1).'timer'};
	$internal_fn_watcher->{fileno($sck1).'timer'} = EV::timer $c1->{'timeout'}, 0, $callback;

};



my $connectsub = sub{
	my ($spv,$ipaddress,$port) = @_;
	my $sck1;
	#warn "Doing connection now, part 1\n";
	
	my $internal_fn_watcher = $fn_to_watcher;
	my $rst1 = $resettimeout;
	
	eval{
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm 5;
		$sck1 = new IO::Socket::INET (
			PeerHost => $ipaddress,
			PeerPort => $port,
			Proto => 'tcp',
		) or die "ERROR in Socket Creation : $!\n";
		alarm 0;
		#warn "Doing connection now, part 2\n";
		
		# I/O watcher
		$internal_fn_watcher->{fileno($sck1)} = EV::io $sck1, EV::READ | EV::WRITE, sub {
			my ($w, $revents) = @_; # all callbacks receive the watcher and event mask
			my $sck2 = $sck1;
			my $sfn = fileno($sck2);
			my $spv2 = $spv;
			my $rst2 = $rst1;
			#warn "in callback with socket=$sfn\n";
			if(!defined $sfn || $sfn < 1){
				warn "socket has closed\n";
				my $ifw2 = $internal_fn_watcher;
				delete $ifw2->{fileno($sck1)};
				return undef;
			}
			else{
				#warn "socket=$sfn\n";
			}
			
			# on read
			if($revents & EV::READ){
				$spv2->peer_by_fileno($sfn)->read_data();
				if(defined $spv2->peer_by_fileno($sfn) && $spv2->peer_by_fileno($sfn)->write() > 0){
					warn "setting eventmask to read/write\n";
					$w->events(EV::READ | EV::WRITE);
				}
				
				# reset timeout
				$rst2->($spv2,$sck2);
			}
			
			# on write
			if(defined $spv2->peer_by_fileno($sfn) && $revents & EV::WRITE ){
				if(defined $spv2->peer_by_fileno($sfn) && $spv2->peer_by_fileno($sfn)->write() > 0){
					$spv2->peer_by_fileno($sfn)->write_data();
				}
				else{
					#warn "setting eventmask to just read\n";
					$w->events(EV::READ );
				}				
			}
		};
	};
	my $error = $@;
	if($error){
		alarm 0;
		warn "bad connection, error=$error";
		delete $internal_fn_watcher->{fileno($sck1)};
		return undef;
	}
	else{
		#warn "Doing connection now, part 3\n";
		return $sck1;
	}
};

my $markwritesub = sub{
	my ($sck1) = (shift);
	
	my $internal_fn_watcher = $fn_to_watcher;
	if(defined $internal_fn_watcher->{fileno($sck1)}){
		$internal_fn_watcher->{fileno($sck1)}->events(EV::READ | EV::WRITE);	
	}
	
};


my $loopsub = sub{
	my ($spv,$connectsub) = (shift,shift);
	
	#my $w = EV::idle(sub{
		#warn "activating peer\n";
		#$spv->activate_peer($connectsub);
	#});
	#$w->events(EV::MINPRI);
	
	$EV::DIED = sub{
		my $error = $@;
		die "failed. error=$error\n";
	};
	
	warn "entering loop";
	EV::run;
};


=pod

---+ Initialization

Create an spv object and have it connect to one peer.



q6m5jhenk33wm4j4.onion
10.19.202.164

=cut

my $spv = CBitcoin::SPV->new({
	'address' => '10.19.202.164',
	'port' => 8333,
	'isLocal' => 1,
	'connect sub' => $connectsub,
	'mark write sub' => $markwritesub 
});

$spv->add_peer_to_db(pack('Q',1),'10.19.202.164','8333');		



=pod

Then, put some fresh, online nodes into the peer pool.  After that, run the event loop.

q6m5jhenk33wm4j4.onion:8333



foreach my $node ('66.43.209.193','174.31.94.104','184.107.155.82',
	'81.61.174.113','104.143.51.43','207.255.174.192',
	'98.127.236.49','68.83.248.43','97.124.176.136'
){
	$spv->add_peer_to_db(pack('Q',1),$node,'8333');		
}
=cut


$spv->activate_peer();


$spv->loop($loopsub,$connectsub);

warn "no more connections, add peers and try again\n";


__END__

