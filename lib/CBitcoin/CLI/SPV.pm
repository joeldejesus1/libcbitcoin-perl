package CBitcoin::CLI::SPV;


use strict;
use warnings;
use CBitcoin;
use CBitcoin::SPV;
use CBitcoin::DefaultEventLoop;
use CBitcoin::Utilities;

use constant {
        ADDNODE   => 1
        ,REMOVENODE   => 2
        ,ADDWATCH   => 3
        ,REMOVEWATCH   => 4
};
use Encode;

use Data::Dumper;


=pod

---+ Utilities

=cut

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
			$options->{'clientname'} = $1;
		}
		elsif($arg =~ m/^\-\-clientname\=(.*)$/){
			die "bad formatting for clientname, did you forget quotes? \"\"\n";
		}
	}
	return $options;
}

=pod

---+ CLI

=cut


our $cli_mapper;

=pod

---++ read_cmd_spv

This starts an spv process.


cbitcoin spv --client="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/" --address=127.0.0.1 --port=8333 --timeout=180

=cut

BEGIN{
	$cli_mapper->{'cmd'}->{'spv'} = \&read_cmd_spv;
}

sub read_cmd_spv{
	my $options = {
		'node' => [],'watch' => []
		,'address' => '127.0.0.1'
		,'port' => 8333
		,'timeout' => 180
		,'daemon' => 0
		,'client name' => ''
	};

	$options = parser($options,@_);
	
	# set up the bloom filter
	my $bloomfilter = CBitcoin::BloomFilter->new({
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
	
	
	
	my $spv = CBitcoin::SPV->new({
		'client name' => $options->{'clientname'},
		'address' => $options->{'address'},	'port' => $options->{'port'}, # this line is for the purpose of creating version messages (not related to the event loop)
		'isLocal' => 1,
		'read buffer size' => 8192*4, # the spv code does have access to the file handle/socket
		'bloom filter' => $bloomfilter,
		'event loop' => CBitcoin::DefaultEventLoop->new({
			'timeout' => $options->{'timeout'}
		})
	});
	
	# load in the addresses
	foreach my $node (@{$options->{'node'}}){
		$spv->add_peer_to_inmemmory(pack('Q',1),$node->[0],$node->[1]);
	}
	
	
	# activate only one peer, and let the $spv figure out how many peers to activate later on
	$spv->activate_peer();
	
	$spv->loop();
	
	return undef;

}

=pod

---++ read_cmd_addwatch

This starts an spv process.

=cut
BEGIN{
	$cli_mapper->{'cmd'}->{'cmd'} = \&read_cmd_sendcmd;
}

sub read_cmd_sendcmd{
	my $options = parser(undef,@_);
	
	my @messages;
	
	# 'node' => [],'watch' => []
	my @addr;
	foreach my $node (@{$options->{'node'}}){
		# node format: address, port, services
		
		# addr format: time, services, ipaddress, port
		my @out;
		$out[2] = $node->[0];
		$out[3] = pack
		
		#$payload .= $node->[0].','.$node->[1]."\n";
		if(defined $node->[2] && $node->[2] =~ m/^([0-9a-fA-F]{16})$/){
			$out[1] = pack('H*',$1);
		}
		elsif(defined $node->[2]){
			die "services in bad format";
		}
		else{
			$out[1] = pack('Q',0);
		}
		#unshift(@{$node},time(),);
		push(@addr,$node);
	}
	if(0 < scalar(@addr)){
		push(@messages,CBitcoin::Message::serialize(
			CBitcoin::Utilities::serialize_addr(@addr),
			'addr',
			CBitcoin::Message::MAINNET
		));		
	}
	
	if(0 < scalar(@{$options->{'watch'}})){
		push(@messages,CBitcoin::Message::serialize(
			Encode::encode('UTF-8', join("\n",@{$options->{'watch'}}), Encode::FB_CROAK),
			'custaddwatch',
			CBitcoin::Message::MAINNET
		));		
	}	

	

	
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