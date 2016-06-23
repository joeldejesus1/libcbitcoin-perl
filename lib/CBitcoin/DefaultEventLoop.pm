package CBitcoin::DefaultEventLoop;

use strict;
use warnings;

use IO::Socket::INET;
use IO::Socket::Socks;
use IO::Epoll;
use EV;


=pod

---+ constructor

=cut


=pod

---++ new

This subroutine creates all of the closures (anonymous subs) needed to make the event loop work.  The author of this module finds himself using multiple event loops over time.  Therefore, he wanted to separate the SPV code from the event loop code by as much as possible.  The unfortunate side effect is having an ugly setup sub.

<verbatim>$eventloop =  {
	'mode setting' => $ms
	,'reset timeout' => $rt
	,'connectsub' => $connectsub
	,'markwritesub' => $markwritesub 
	,'loop' => $loopsub 
}</verbatim>

=cut


sub new {
	my ($package,$config) = @_;

	
	$config = {
		'timeout' => 60
	} unless defined $config;
	
	local $| = 1;
	
	my $gen_block = CBitcoin::Block->genesis_block();
	#warn "Hash=".$gen_block->hash_hex."\n";
	#warn "prevBlockHash=".$gen_block->prevBlockHash_hex."\n";
	#warn "Data=".unpack('H*',$gen_block->data)."\n";
	
	die "bad genesis block" unless defined $gen_block;
	
	# set umask so that files/directories will be 0700 or 0600
	
	umask(077);
	#`mv /tmp/spv/active/* /tmp/spv/pool/`;
	
	# we need to define a connectsub, markwritesub, loopsub.
	
	
	my $fn_to_watcher = {};
	
	
	
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
		return undef unless defined $sck1 && 0 < fileno($sck1);
		
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
	
	# figure out socks 5 stuff
	my $socks5 = add_socks5($config->{'socks5 address'},$config->{'socks5 port'});
	
	
	my $connectsub = sub{
		my ($spv,$ipaddress,$port) = @_;
		my $sck1;
		my $c2 = $config;
		my $socks5_2 = $socks5;
		#warn "Doing connection now, part 1\n";
		
		my $internal_fn_watcher = $fn_to_watcher;
		my $rst1 = $resettimeout;
		
		
		
		
		eval{
			local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
			alarm 5;

			if(defined $socks5_2){
				warn "connection to $ipaddress via socks5\n";
				$sck1 = IO::Socket::Socks->new(
					ProxyAddr   => $socks5_2->{'address'},
					ProxyPort   => $socks5_2->{'port'},
					ConnectAddr => $ipaddress,
	    			ConnectPort => $port,
				) || (alarm 0 && die $SOCKS_ERROR);
			}
			else{
				warn "connection using normal INET\n";
				$sck1 = new IO::Socket::INET (
					PeerHost => $ipaddress,
					PeerPort => $port,
					Proto => 'tcp',
				);
			}
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
			delete $internal_fn_watcher->{fileno($sck1)} if defined $sck1;
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
	
	
	my $this = {
		'mode setting' => $mode_setting
		,'reset timeout' => $resettimeout
		,'connect' => $connectsub
		,'mark write' => $markwritesub 
		,'loop' => $loopsub
		,'config' => $config
	};
	bless($this,$package);
	
	return $this;
}

=pod

---+ Getters/Setters

=cut

sub set_mode{
	return shift->{'mode setting'};
}

sub reset_timeout {
	return shift->{'reset timeout'};
}

sub connect {
	return shift->{'connect'};
}

sub mark_write {
	return shift->{'mark write'};
}

sub loop {
	return shift->{'loop'};
}

=pod

---+ utilities

=cut

=pod

---++ add_socks5

Validate and untaint a socks5 host.

=cut

sub add_socks5 {
	my ($address,$port) = @_;
	#warn "add socks not done";
	return undef unless defined $address && $address =~ m/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/;
	#warn "add socks done";
	my $ref;
	$ref->{'address'} = $1;
	if(defined $port && $port =~ m/^(\d+)$/){
		$ref->{'port'} = $1;
	}
	elsif(!defined $port){
		$ref->{'port'} = 9050;
	}
	else{
		$ref->{'port'} = 9050;
	}
	return $ref;
}





1;