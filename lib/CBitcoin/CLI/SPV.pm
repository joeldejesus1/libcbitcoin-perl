package CBitcoin::CLI::SPV;


use strict;
use warnings;
use CBitcoin;
use CBitcoin::SPV;
use CBitcoin::DefaultEventLoop;
use CBitcoin::Utilities;
use Fcntl qw(:DEFAULT :flock SEEK_END);
use Digest::SHA;
use Log::Log4perl;

use constant {
        ADDNODE   => 1
        ,REMOVENODE   => 2
        ,ADDWATCH   => 3
        ,REMOVEWATCH   => 4
};
use Encode;

use Data::Dumper;


my $logger;

=pod

---+ Utilities

=cut

=pod

---++ logging_conf

Return a reference?

=cut

sub logging_conf {
	my $fp = shift;
	if(defined $fp){
		Log::Log4perl::init( $fp );
	}
	else{
		my $conf = q(
log4perl.rootLogger = DEBUG, screen

log4perl.appender.screen = Log::Log4perl::Appender::Screen
log4perl.appender.screen.stderr = 1
log4perl.appender.screen.layout = PatternLayout
log4perl.appender.screen.layout.ConversionPattern = %d %p> %F{1}:%L %M - %m%n
		);
		Log::Log4perl::init( \$conf );
		$logger = Log::Log4perl->get_logger();
		$logger->debug("debugging!");
	}

}


=pod

---++ validate_filepath($file_path,$prefix)

Strip the prefix and run a regex to validate the file path

A full path must always be provided.

=cut

sub validate_filepath {
	my $fp = shift;
	my $prefix = shift;
	$prefix = '' unless defined $prefix;
	return undef unless defined $fp && 0 < length($fp);
	
	my $prefix_check = substr($fp,0,length($prefix));
	return undef unless $prefix_check eq $prefix;
	
	$fp = substr($fp,length($prefix));
	
	my $leading_slash = 0;
	my @untainted;
	foreach my $dir (split('/',$fp)){
		if($dir eq '' && !$leading_slash){
			$leading_slash = 1;
			push(@untainted,'');
			next;
		}
		elsif($dir eq ''){
			return undef;
		}
		
		
		if($dir =~ m/^([^*&%\s]+)$/){
			push(@untainted,$1);
		}
		else{
			return undef;
		}
	}
	return join('/',@untainted);
}

=pod

---++ parser

'node'

=cut

sub parser {
	my $ref = shift;
	my $options;
	if(ref($ref) eq 'HASH'){
		$options  = $ref ;
	}
	else{
		$options = {'node' => [],'watch' => []};
	}
	
	foreach my $arg (@_){
		if($arg =~ m/^\-\-node\=([0-9a-zA-Z]+\.onion|[0-9\.]+)\:(\d+)$/){
			push(@{$options->{'node'}},[$1,$2]);
		}
		elsif($arg =~ m/^\-\-node\=(.*)$/){
			die "bad formatting for node\n";
		}
		
		elsif($arg =~ m/^\-\-watch\=([0-9a-zA-Z]+)$/){
			push(@{$options->{'watch'}},$1);
		}
		elsif($arg =~ m/^\-\-watch\=(.*)$/){
			die "bad formatting for watch\n";
		}
		
		
		elsif($arg =~ m/^\-\-address\=([0-9a-zA-Z]+\.onion|[0-9\.]+)\:(\d+)$/){
			$options->{'address'} = $1;
			$options->{'port'} = $2;
		}
		elsif($arg =~ m/^\-\-address\=(.*)$/){
			die "bad formatting for address\n";
		}
		
		elsif($arg =~ m/^\-\-timeout\=(\d+)$/){
			$options->{'timeout'} = $1;
		}
		elsif($arg =~ m/^\-\-timeout\=(.*)$/){
			die "bad formatting for timeout\n";
		}
		
		elsif($arg =~ m/^\-\-clientname\=\"(.*)\"$/){
			#warn "parse client name=[$1][$arg]\n";
			$options->{'client name'} = $1;
		}
		elsif($arg =~ m/^\-\-clientname\=(.*)$/){
			die "bad formatting for clientname, did you forget quotes? \"\"\n";
		}
		
		elsif(validate_filepath($arg,'--logconf=')){
			#warn "logconf ARG=$arg\n";
			$options->{'logconf'} = validate_filepath($arg,'--logconf=');
		}
		elsif($arg =~ m/^\-\-logconf\=(.*)$/){
			die "bad formatting for log conf file\n";
		}
		
		elsif(validate_filepath($arg,'--dbpath=')){
		#	warn "dbpath ARG=$arg\n";
			$options->{'db path'} = validate_filepath($arg,'--dbpath=');
		}
		elsif($arg =~ m/^\-\-dbpath\=(.*)$/){
			die "bad formatting for dbpath\n";
		}
		
		
		elsif($arg =~ m/^\-\-inputfd\=(\d+)$/){
#			warn "Got xyz inputfd=$1";
			$options->{'inputfd'} = $1;
		}
		elsif($arg =~ m/^\-\-inputfd\=(.*)$/){
			die "bad file descriptor";
		}
		
		elsif($arg =~ m/^\-\-outputfd\=(\d+)$/){
			#warn "Got xyz outputfd=$1";
			$options->{'outputfd'} = $1;
		}
		elsif($arg =~ m/^\-\-outputfd\=(.*)$/){
			die "bad file descriptor";
		}
		
	}
	
	#warn "Got xyz Both[".$options->{'inputfd'}."][".$options->{'outputfd'}."]\n";
	
	return $options;
}

=pod



---+ CLI

=cut


our $cli_mapper;

=pod

---++ read_cmd_bloomfilter

Set a bloom filter.  All transactions that fit into the bloom filter are sent back out via an mqueue.

To send the bloomfilter via the command line:<verbatim>generate-bloomfilter.pl | cbitcoin bloomfilter</verbatim>
   * As is seen in this example, the bloom filter has to be sent in via stdin.

=cut

BEGIN{
	$cli_mapper->{'cmd'}->{'bloomfilter'} = \&read_cmd_bloomfilter;
}

sub read_cmd_bloomfilter{
	#my $options = parser(undef,@_);
	#logging_conf($options->{'logconf'});
	
	my $buf;
	my ($m,$n,$bfdata) =(0,0,'');
	my $sha = Digest::SHA->new(256);
	binmode(STDIN);
	while($m = sysread(STDIN,$buf,8192)){
		$n += $m;
		$sha->add($buf);
		$bfdata .= $buf;
	}
	# once EOF is received, then send the bloom filter out
	my $fname;
	open(my $fh,'<','/dev/urandom');
	sysread($fh,$fname,8);
	close($fh);
	
	# Need to store the file on disk
	my $fname_hex = lc(unpack('H*',$fname));
	if($fname_hex =~ m/^([0-9a-f]+)$/){
		$fname_hex = $1;
	}
	
	unless(sysopen ($fh, '/tmp/'.$fname_hex.'.bf', O_RDWR|O_CREAT, 0755)){
		return undef;
	}
	
	my $digest = $sha->digest;
	
	# format bfdata
	($m,$n) = (0,length($bfdata));
	while(0 < $n - $m){
		$m += syswrite($fh,$bfdata,$n - $m, $m);
	}
	close($fh);
	
	my $msg = CBitcoin::Message::serialize(
		$sha->digest.$fname,
		'custsetbf',
		$CBitcoin::network_bytes
	);
	
	
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $mqin = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,'in')
		,'handle type' => 'write only'
		,'no hash' => 1
	});
	warn "Sending messages to the spv process with filename=$fname\n";
	
	$mqin->send($msg);
	
	return undef;
}

=pod

---++ read_cmd_spv

This starts an spv process.


cbitcoin spv --client="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/" --address=127.0.0.1 --port=8333 --timeout=180

=cut

BEGIN{
	$cli_mapper->{'cmd'}->{'spv'} = \&read_cmd_spv;
}

sub read_cmd_spv{
	
	$0 = 'CBitcoin::SPV';
	
	my $options = {
		'node' => [],'watch' => []
		,'address' => '127.0.0.1'
		,'port' => 8333
		,'timeout' => 180
		,'daemon' => 0
		,'client name' => ''
	};

	$options = parser($options,@_);
	logging_conf($options->{'logconf'});
	
	# set up the bloom filter
	my $bloomfilter;
	if(defined $options->{'watch'}){
		$bloomfilter = CBitcoin::BloomFilter->new({
			'FalsePostiveRate' => 0.001,
			'nHashFuncs' => 1000 
		});
		
		foreach my $addr (@{$options->{'watch'}}){
			my $script = CBitcoin::Script::address_to_script($addr);
			die "address($addr) is not valid" unless defined $script && 0 < length($script);
			$script = CBitcoin::Script::serialize_script($script);
			die "address($addr) is not valid" unless defined $script && 0 < length($script);
			$bloomfilter->add_script($script);
			#push(@scripts,$script);
		}		
	}

	
	my $eventloop_options = {
		'timeout' => $options->{'timeout'}
	};
	
	if(defined $options->{'inputfd'}){
		#$logger->debug("setting inputfd=".$options->{'inputfd'});
		#warn "setting inputfd=".$options->{'inputfd'};
		$eventloop_options->{'inputfd'} = $options->{'inputfd'};
	}
	if(defined $options->{'outputfd'}){
		#$logger->debug("setting outputfd=".$options->{'outputfd'});
		#warn "setting outputfd=".$options->{'outputfd'};
		$eventloop_options->{'outputfd'} = $options->{'outputfd'};
	}	
	
	#warn "prestart cn=".$options->{'outputfd'}."\n";
	my $args = {
		'client name' => $options->{'client name'},
		'address' => $options->{'address'},	'port' => $options->{'port'}, # this line is for the purpose of creating version messages (not related to the event loop)
		'isLocal' => 1,
		'read buffer size' => 8192*4, # the spv code does have access to the file handle/socket
		'db path' => $options->{'db path'},
		'event loop' => CBitcoin::DefaultEventLoop->new($eventloop_options),
	};
	if(defined $bloomfilter){
		$args->{'bloom filter'} = $bloomfilter;
	}
	my $spv = CBitcoin::SPV->new($args);
	
	# load in the addresses
	foreach my $node (@{$options->{'node'}}){
		$spv->add_peer_to_inmemmory(pack('Q',1),$node->[0],$node->[1]);
	}
	
	$SIG{'PIPE'} = 'IGNORE';
	
	
	# activate only one peer, and let the $spv figure out how many peers to activate later on
	$spv->activate_peer();
	
	$spv->loop();
	
	return undef;

}

=pod

---++ read_cmd_addwatch

This sends a command to an spv process that is already running.

cbitcoin cmd --node=122.10.95.70:8333 --node=103.208.86.32:8333

=cut

BEGIN{
	$cli_mapper->{'cmd'}->{'cmd'} = \&read_cmd_sendcmd;
}

sub read_cmd_sendcmd{
	my $options = parser(undef,@_);
	logging_conf($options->{'logconf'});
	
	my @messages;
	
	# 'node' => [],'watch' => []
	my @addr;
	foreach my $node (@{$options->{'node'}}){
		# node format: address, port, services
		$node->[2] = 0 unless defined $node->[2];
		# addr format: time, services, ipaddress, port
		my @out = (time(),$node->[2],$node->[0],$node->[1]);		
		
		#unshift(@{$node},time(),);
		push(@addr,\@out);
	}
	if(0 < scalar(@addr)){
		push(@messages,CBitcoin::Message::serialize(
			CBitcoin::Utilities::serialize_addr(@addr),
			'addr',
			$CBitcoin::network_bytes
		));		
	}
	
	#if(0 < scalar(@{$options->{'watch'}})){
	#	push(@messages,CBitcoin::Message::serialize(
	#		Encode::encode('UTF-8', join("\n",@{$options->{'watch'}}), Encode::FB_CROAK),
	#		'custaddwatch',
	#		$CBitcoin::network_bytes
	#	));		
	#}	

	

	
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $mqin = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,'in')
		,'handle type' => 'write only'
		,'no hash' => 1
	});
	warn "Sending messages to the spv process\n";
	
	foreach my $msg (@messages){
		$mqin->send($msg);
	}
	
	return undef;
}


=pod

---++ read_cmd_readdata

Read data coming off the message queue and print it to stdout.

<verbatim>cbitcoin read</verbatim>

=cut

BEGIN{
	$cli_mapper->{'cmd'}->{'read'} = \&read_cmd_readdata;
}

sub read_cmd_readdata{
	my ($our_uid,$our_pid) = ($>,$$); #real uid
	my $mqout = Kgc::MQ->new({
		'name' => join('.','spv',$our_uid,'out')
		,'handle type' => 'read only'
		,'no hash' => 1
	});
	
	while(my $msg_data = $mqout->receive()){
		print STDERR "$msg_data\n++++++++++++\n";
	}
	
}
=pod

---+ run_cli_args

And execute the subroutine.

=cut

sub run_cli_args{
	my $cmd = shift;
	
	die "no command given" unless defined $cmd;
	
	if(defined $cli_mapper->{'cmd'}->{$cmd} && ref($cli_mapper->{'cmd'}->{$cmd}) eq 'CODE'){
		# run the sub, don't bother looking for a return value
		$cli_mapper->{'cmd'}->{$cmd}->(@_);
	}
	else{
		die "$cmd is not a valid command";
	}
}


















1;