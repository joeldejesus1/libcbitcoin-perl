use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::SPV;
use CBitcoin::DefaultEventLoop;



use Test::More tests => 1;

ok(1,'nothing to test');

=pod

---+ Set Up Wallet

=cut

my $bloomfilter = CBitcoin::BloomFilter->new({
	'FalsePostiveRate' => 0.001,
	'nHashFuncs' => 1000 
});

########### Set up a wallet ######################
# transactions sending money to these addresses are in block 120383
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

=pod

---+ Initialization

Create an spv object and have it connect to one peer.


	'connect sub' => $el->{'connect'},
	'mark write sub' => $el->{'mark write'} ,

=cut

my $spv = CBitcoin::SPV->new({
	'client name' => '/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/',
	'address' => '10.202.177.155',	'port' => 8333, # this line is for the purpose of creating version messages (not related to the event loop)
	'isLocal' => 1,
	'read buffer size' => 8192*4, # the spv code does have access to the file handle/socket
	'bloom filter' => $bloomfilter,
	'event loop' => CBitcoin::DefaultEventLoop->new({
		'timeout' => 180,
		'socks5 address' => '127.0.0.1',
		'socks5 port' => 9999
	})
});

#die "no socks5" unless $spv->{'socks5'};

# q6m5jhenk33wm4j4.onion

#$spv->add_peer_to_inmemmory(pack('Q',1),'127.0.0.1','38333');		
$spv->add_peer_to_inmemmory(pack('Q',1),'10.202.177.155','8333'); # q6m5jhenk33wm4j4.onion
$spv->add_peer_to_inmemmory(pack('Q',1),'10.193.178.58','8333'); # l4xfmcziytzeehcz.onion
$spv->add_peer_to_inmemmory(pack('Q',1),'10.251.166.108','8333'); # gb5ypqt63du3wfhn.onion
$spv->add_peer_to_inmemmory(pack('Q',1),'10.243.114.46','8333'); # syvoftjowwyccwdp.onion

# jhjuld3x27srjpby.onion 10.211.136.179
# a6obdgzn67l7exu3.onion 10.207.89.205
# 4okypmflcectloz5.onion 10.201.181.38

$spv->activate_peer();


=pod

---+ Enter Event Loop

=cut


$spv->loop();

warn "no more connections, add peers and try again\n";

print "Bail out!";


__END__

