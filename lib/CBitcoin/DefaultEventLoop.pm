package CBitcoin::DefaultEventLoop;

use strict;
use warnings;

use IO::Socket::INET;
use IO::Socket::Socks;
use IO::Epoll;
use EV;
use Kgc::MQ;
use  Log::Log4perl;


my $logger = Log::Log4perl->get_logger();

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
	
	my $evloop = EV::Loop->new();
	
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
		
		my $evloop2 = $evloop;
		my $internal_fn_watcher = $fn_to_watcher;
		my $c1 = $config;
		
	
		$mode_setting->(1);
		
		# callback sub
		my $cbhash = {'x' => 1};
		$cbhash->{'x'} = sub {
			$logger->warn("is called after ".$config->{'timeout'}."s");
			my $evloop3 = $evloop2;
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
				$ifw->{fileno($sck2).'timer'} = $evloop3->timer(30, 0, $cb2);
			}
			else{
				$logger->warn("connection timed out");
				$spv_in->close_peer(fileno($sck2));
				
			}
			
			
		};
		my $callback = $cbhash->{'x'};
		delete $internal_fn_watcher->{fileno($sck1).'timer'};
		$internal_fn_watcher->{fileno($sck1).'timer'} = $evloop2->timer($c1->{'timeout'}, 0, $callback);
	
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
		my $evloop2 = $evloop;
		
		
		
		eval{
			local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
			alarm 15;
			chomp($ipaddress);
			chomp($port);

			if($ipaddress =~ m/^([0-9a-zA-Z\.]+)$/){
				$ipaddress = $1;
			}
			
			if($port =~ m/^(\d+)$/){
				$port = $1;
			}
			
			if(defined $socks5_2){
				$logger->info("connection to $ipaddress via socks5");
				$sck1 = IO::Socket::Socks->new(
					ProxyAddr   => $socks5_2->{'address'},
					ProxyPort   => $socks5_2->{'port'},
					ConnectAddr => $ipaddress,
	    			ConnectPort => $port,
				) || (alarm 0 && die $SOCKS_ERROR);
			}
			else{
				$logger->info("connection using normal INET to ($ipaddress:$port)");
				

				
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
					$logger->info("socket has closed");
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
						$logger->debug("setting eventmask to read/write");
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
			$internal_fn_watcher->{fileno($sck1)} = $evloop2->io($sck1, EV::READ | EV::WRITE, $readwritesub);
			
			# the sub is $sub->($timeout)
			$spv->peer_set_sleepsub($sck1,sub{
				my ($peer2,$timeout) = @_;
				my $evloop3 = $evloop2;
				my $spv2 = $spv;
				my $sck2 = $sck1;
				my $rws2 = $readwritesub;
				my $ifw2 = $internal_fn_watcher;
				#return undef if $spv2->{'peer rate limiter'}->{fileno($sck2)};
				
				# set watcher to read only
				$logger->debug("Peer is writing too much data.");
				
				return undef if $peer2->{'sleeping'};
				$peer2->{'sleeping'} = 1;
				
				$ifw2->{fileno($sck2)}->events(EV::READ);
				
				$ifw2->{fileno($sck2).'ratelimiter'} = $evloop3->timer($timeout, 0, sub {
					my $sck3 = $sck2;
					my $spv3 = $spv2;
	     			my $ifw3 = $ifw2;
	     			delete $ifw3->{fileno($sck3).'ratelimiter'};
	     			$peer2->{'sleeping'} = 0;
	     			$logger->debug("Adding peer socket back in");
	     			$ifw3->{fileno($sck3)}->events(EV::READ | EV::WRITE);
	     			
				});
			});
		};
		my $error = $@;
		if($error){
			alarm 0;
			$logger->error("bad connection, error=$error");
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
		my $evloop2 = $evloop;
		#my $w = EV::idle(sub{
			#warn "activating peer\n";
			#$spv->activate_peer($connectsub);
		#});
		#$w->events(EV::MINPRI);
		
		$EV::DIED = sub{
			my $error = $@;
			die "failed. error=$error\n";
		};
		
		$logger->info("entering loop");
		$evloop2->run();
	};
	
	
	my $this = {
		'mode setting' => $mode_setting
		,'reset timeout' => $resettimeout
		,'connect' => $connectsub
		,'mark write' => $markwritesub 
		,'loop' => $loopsub
		,'config' => $config
		,'event loop socket' => $evloop
		,'cncspv' => {}
		,'cnc in' => {}
		,'cnc out' => {}
		,'spv pids' => []
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

sub ev_socket {
	return shift->{'event loop socket'};
}

sub spv_pids {
	return shift->{'spv pids'};
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

=pod

---++ cncspv_add($spv)->[$pid1,$pid2,...]

Scans for new mqueues and addes new sockets to allow communication with another spv process.

=cut

sub cncspv_add {
	my ($this,$spv) = @_;
	
	return undef if defined $this->{'cncspv_add done'};
	$this->{'cncspv_add done'} = 1;
	
	$this->ev_socket()->stat ('/dev/mqueue', 0, sub{
		my $t1 = $this;
		my $spv2 = $spv;
		$t1->cncspv_add_callback($spv2);
	});
}


sub cncspv_add_callback {
	my ($this,$spv) = @_;
	
	my $dirfp = '/dev/mqueue';
	opendir(my $fh,$dirfp);
	my @x = readdir($fh);
	closedir($fh);
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $loop = $this->ev_socket();
	my @targets;
	foreach my $spv_process (@x){
		next if $spv_process eq '.' || $spv_process eq '..';
		if($spv_process =~ m/^spv\.(\d+)\.(\d+)$/){
			my ($uid,$pid) = ($1,$2);
			$logger->debug("Got ($uid,$pid)");
			next if $our_uid != $uid || $our_pid == $pid;
			next if defined $this->{'cncspv'}->{$pid};
			$logger->debug("adding pid=$pid");
			push(@targets,$pid);
			my $mq = Kgc::MQ->new({
				'name' => join('.','spv',$uid,$pid)
				,'handle type' => 'write only'
				,'no hash' => 1
			});
			$this->{'cncspv'}->{$pid}->{'mq'} = $mq;
			$this->{'cncspv'}->{$pid}->{'fd'} = $this->{'cncspv'}->{$pid}->{'mq'}->file_descriptor();
			$this->{'cncspv'}->{$pid}->{'callback'} = sub{
				my ($w, $revents) = @_;
				my $t1 = $this;
				my $spv2 = $spv;
				my $mq2 = $mq;
				my $pid2 = $pid;
				my $msg = $spv2->cnc_send_message_data($pid2,$t1->{'cncspv'}->{$pid2}->{'mark off'});
				$logger->debug("sending message for pid=$pid2");
				return undef unless defined $msg && 0 < length($msg);
				$mq2->send($msg);
				#$spv2->cnc_receive_message($mq2->receive());
			};
			$this->{'cncspv'}->{$pid}->{'watcher'} = $loop->io(
				$this->{'cncspv'}->{$pid}->{'fd'}
				,EV::WRITE
				,$this->{'cncspv'}->{$pid}->{'callback'}
			);
			$this->{'cncspv'}->{$pid}->{'mark off'} = sub{
				my $t1 = $this;
				my $pid2 = $pid;
				$logger->debug("pid=$pid2 marking off");
				delete $t1->{'cncspv'}->{$pid2}->{'watcher'};
				return 	$t1->{'cncspv'}->{$pid2}->{'mark write'};				
			};
			$this->{'cncspv'}->{$pid}->{'mark write'} = sub{
				my $t1 = $this;
				my $loop2 = $loop;
				my $pid2 = $pid;
				$logger->debug("pid=$pid2 marking write");
				if(defined $t1->{'cncspv'}->{$pid2}->{'watcher'}){
					$t1->{'cncspv'}->{$pid2}->{'watcher'}->events(EV::WRITE);
				}
				else{
					$t1->{'cncspv'}->{$pid2}->{'watcher'} = $loop2->io(
						$t1->{'cncspv'}->{$pid2}->{'fd'}
						,EV::WRITE
						,$t1->{'cncspv'}->{$pid2}->{'callback'}
					);
				}
			};
		}
	}
	
	$this->{'spv pids'} = \@targets;
}

=pod

---++ cncstdio_add($spv)

Add an command and control socket to allow communication with another spv process.

=cut

sub cncstdio_add {
	my ($this,$spv) = @_;
	
	my $loop = $this->ev_socket();
	warn "Hello - 1\n";
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $mqin = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,'in')
		,'handle type' => 'read only'
		,'no hash' => 1
	});
	$this->{'cnc in'}->{'fd'} = $mqin->file_descriptor();
	$this->{'cnc in'}->{'mq'} = $mqin;
	$this->{'cnc in'}->{'watcher'} = $loop->io(
		$this->{'cnc in'}->{'fd'}
		,EV::READ
		,sub{
			my ($w, $revents) = @_;
			my $spv2 = $spv;
			my $mqin2 = $mqin;
			$spv2->cnc_receive_message('cnc in',$mqin2->receive());
		}
	);
	
	warn "Hello - 2\n";
	
	my $mqout = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,'out')
		,'handle type' => 'write only'
		,'no hash' => 1
	});
	$this->{'cnc out'}->{'fd'} = $mqout->file_descriptor();
	$this->{'cnc out'}->{'mq'} = $mqout;
	$this->{'cnc out'}->{'callback'} = sub{
		my ($w, $revents) = @_;
		my $spv2 = $spv;
		my $mqout2 = $mqout;
		my $t1 = $this;
		warn "running callback on out\n";
		my $msg = $spv2->cnc_send_message_data('cnc out',$t1->{'cnc out'}->{'mark off'});
		return undef unless defined $msg && 0 < length($msg);
		$mqout2->send($msg);
		#$spv2->receive_message($mqout2->receive());
	};
	$this->{'cnc out'}->{'watcher'} = $loop->io(
		$this->{'cnc out'}->{'fd'}
		,EV::WRITE
		,$this->{'cnc out'}->{'callback'}
	);
	# for mark off, return the sub to reactivate the watcher
	$this->{'cnc out'}->{'mark off'} = sub{
		warn "marking off on cnc out\n";
		my $t1 = $this;
		delete $t1->{'cnc out'}->{'watcher'};
		return 	$t1->{'cnc out'}->{'mark write'};
	};
	# this is called only after calling mark off
	$this->{'cnc out'}->{'mark write'} = sub{
		my $t1 = $this;
		my $loop2 = $loop;
		warn "marking write on cnc out\n";
		if(defined $t1->{'cnc out'}->{'watcher'}){
			$t1->{'cnc out'}->{'watcher'}->events(EV::WRITE);
		}
		else{
			$t1->{'cnc out'}->{'watcher'} = $loop2->io(
				$t1->{'cnc out'}->{'fd'}
				,EV::WRITE
				,$t1->{'cnc out'}->{'callback'}
			);
		}
	};
	warn "Hello - 3\n";
}


=pod

---++ cncspv_own($spv)

Set up the mqueue so that this process can listen for messages from other spv processes.

Run this subroutine just before starting the loop in an SPV process.

=cut

sub cncspv_own{
	my ($this,$spv) = @_;
	return undef if defined $this->{'cnc own'};

	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $mqin = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,$our_pid)
		,'handle type' => 'read only'
		,'no hash' => 1
	});
	
	my $loop = $this->ev_socket();
	
	$this->{'cnc own'}->{'fd'} = $mqin->file_descriptor();
	$this->{'cnc own'}->{'mq'} = $mqin;
	$this->{'cnc own'}->{'watcher'} = $loop->io(
		$this->{'cnc own'}->{'fd'}
		,EV::READ
		,sub{
			my ($w, $revents) = @_;
			my $spv2 = $spv;
			my $mqin2 = $mqin;
			$spv2->cnc_receive_message('cnc own',$mqin2->receive());
		}
	);
	
}

1;