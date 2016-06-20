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
#warn "Hash=".$gen_block->hash_hex."\n";
#warn "prevBlockHash=".$gen_block->prevBlockHash_hex."\n";
#warn "Data=".unpack('H*',$gen_block->data)."\n";

ok($gen_block->{'success'}) || print "Bail out!";

# set umask so that files/directories will be 0700 or 0600

umask(077);
#`mv /tmp/spv/active/* /tmp/spv/pool/`;

# we need to define a connectsub, markwritesub, loopsub.


my $fn_to_watcher = {};

my $config = {
	'timeout' => 60
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
		);
		alarm 0;
		unless(defined $sck1){
			die "ERROR in Socket Creation : $!\n";
		}
		
		
		#warn "Doing connection now, part 2\n";
		
		# I/O watcher
		 
		my $readwritesub = sub {
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
		$internal_fn_watcher->{fileno($sck1)} = EV::io $sck1, EV::READ | EV::WRITE, $readwritesub;
		
		# the sub is $sub->($timeout)
		$spv->peer_set_sleepsub($sck1,sub{
			my ($peer2,$timeout) = @_;
			
			my $spv2 = $spv;
			my $sck2 = $sck1;
			my $rws2 = $readwritesub;
			my $ifw2 = $internal_fn_watcher;
			#return undef if $spv2->{'peer rate limiter'}->{fileno($sck2)};
			
			# set watcher to read only
			warn "Peer is writing too much data.\n";
			
			return undef if $peer2->{'sleeping'};
			$peer2->{'sleeping'} = 1;
			
			$ifw2->{fileno($sck2)}->events(EV::READ);
			
			$ifw2->{fileno($sck2).'ratelimiter'} = EV::timer $timeout, 0, sub {
				my $sck3 = $sck2;
				my $spv3 = $spv2;
     			my $ifw3 = $ifw2;
     			delete $ifw3->{fileno($sck3).'ratelimiter'};
     			$peer2->{'sleeping'} = 0;
     			warn "Adding peer socket back in\n";
     			$ifw3->{fileno($sck3)}->events(EV::READ | EV::WRITE);
     			
			};
		});
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

---+ Set Up Wallet

=cut

my $bloomfilter = CBitcoin::BloomFilter->new({
	'FalsePostiveRate' => 0.001,
	'nHashFuncs' => 1000 
});

########### Set up a wallet ######################
# these are in block 120383
foreach my $addr (
	'1BhT26zK7g9hXb3PDkwenkxpBeGYa6MCK1','1BPxymA3FSdUbfHTEzBycf5CsVbWqDGp6A',
	'1LoZdpsX9c662bKJTpt8cEfANmu8WRKKKN'
){
	my $script = CBitcoin::Script::address_to_script($addr);
	print "Bail out!" unless defined $script && 0 < length($script);
	$script = CBitcoin::Script::serialize_script($script);
	print "Bail out!" unless defined $script && 0 < length($script);
	$bloomfilter->add_script($script);
	#push(@scripts,$script);
}

#########################################################



=pod

---+ Initialization

Create an spv object and have it connect to one peer.



q6m5jhenk33wm4j4.onion
10.19.202.164

=cut
# q6m5jhenk33wm4j4.onion
my $spv = CBitcoin::SPV->new({
	'address' => '127.0.0.1',
	'port' => 8333,
	'isLocal' => 1,
	'connect sub' => $connectsub,
	'mark write sub' => $markwritesub ,
	'read buffer size' => 8192*4,
	'bloom filter' => $bloomfilter
});

# q6m5jhenk33wm4j4.onion

#$spv->add_peer_to_inmemmory(pack('Q',1),'127.0.0.1','38333');		
$spv->add_peer_to_inmemmory(pack('Q',1),'q6m5jhenk33wm4j4.onion','8333');
$spv->add_peer_to_inmemmory(pack('Q',1),'l4xfmcziytzeehcz.onion','8333');
$spv->add_peer_to_inmemmory(pack('Q',1),'gb5ypqt63du3wfhn.onion','8333');
$spv->add_peer_to_inmemmory(pack('Q',1),'syvoftjowwyccwdp.onion','8333');


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

print "Bail out!";

__END__

