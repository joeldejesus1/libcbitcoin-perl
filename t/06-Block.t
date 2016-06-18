use strict;
use warnings;


#use CBitcoin::Block;
require Data::Dumper;
use Test::More tests => 4;

use JSON::XS;
use CBitcoin;
use CBitcoin::Message;
use CBitcoin::Block;
use CBitcoin::Script;
########## Test a raw genesis block ############

my $blk0json = '{
  "hash" : "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "height" : 0,
  "size" : 309
}';
$blk0json = JSON::XS::decode_json($blk0json);
$blk0json->{'hash'} =  join '', reverse split /(..)/, $blk0json->{'hash'} ;

open(my $fh,'<','t/blk0.ser') || print "Bail out!";
binmode($fh);

my $msg = CBitcoin::Message->deserialize($fh);
close($fh);
# $msg->payload()
my $block = CBitcoin::Block->deserialize(pack('H*','0100000000000000000000000000000000000000000000000000000000000000000000003BA3EDFD7A7B12B27AC72C3E67768F617FC81BC3888A51323A9FB8AA4B1E5E4A29AB5F49FFFF001D1DAC2B7C0101000000010000000000000000000000000000000000000000000000000000000000000000FFFFFFFF4D04FFFF001D0104455468652054696D65732030332F4A616E2F32303039204368616E63656C6C6F72206F6E206272696E6B206F66207365636F6E64206261696C6F757420666F722062616E6B73FFFFFFFF0100F2052A01000000434104678AFDB0FE5548271967F1A67130B7105CD6A828E03909A67962E0EA1F61DEB649F6BC3F4CEF38C4F35504E51EC112DE5C384DF7BA0B8D578A4C702B6BF11D5FAC00000000'));

my $est_gen_hash = '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';
$est_gen_hash = join '', reverse split /(..)/, $est_gen_hash;

#warn "hash=".$block->hash_hex."\n";
#warn "hash act=".$est_gen_hash."\n";
#warn "prevHash=".$block->prevBlockHash_hex."\n";
#warn "nonce=".$block->nonce."\n";
#warn "timestamp=".$block->timestamp."\n";
#warn "XO=".$block->hash_hex."\n";
#warn "blk0=".$block->hash_hex."\n[".length($block->hash)."]...".$blk0json->{'hash'}."\n";

ok( $block->{'success'} && $block->hash_hex eq $est_gen_hash, 'Genesis Block' );

my $gen_hash = $block->hash() if $block->{'success'};
#warn "XO=[".unpack('H*',$msg->payload())."]\n";

########## Test a big block ############

my $blk120383json = '{
  "hash" : "0000000000008fdf23e2a8d58a6e47a9f09913ad0b8f8507e0490385fba59ca3",
  "height" : 120383,
  "size" : 99090
}';
$blk120383json = JSON::XS::decode_json($blk120383json);
$blk120383json->{'hash'} =  join '', reverse split /(..)/, $blk120383json->{'hash'} ;

open($fh,'<','t/blk120383.ser') || print "Bail out!";
binmode($fh);
$msg = CBitcoin::Message->deserialize($fh);
close($fh);

$block = CBitcoin::Block->deserialize($msg->payload() );
#warn "blk120383=".$block->hash_hex."\n[".length($block->hash)."]...".$blk120383json->{'hash'}."\n";

ok( 
	$block->{'success'} 
	&& $block->hash_hex eq $blk120383json->{'hash'}
, 'Big Block' );

my $rh = join '', reverse split /(..)/, $block->hash_hex ;

#warn "Block120383 hash=".$rh."\n";

########## Retest Genesis Block ############

$block = CBitcoin::Block->genesis_block();
ok( $block->{'success'} && $block->hash() eq $gen_hash, 'Genesis Block sub' );

#my $newblock = block_BlockFromData(,0);



############## Test Bloom Filter ############
my @scripts;
foreach my $addr (
	'1BhT26zK7g9hXb3PDkwenkxpBeGYa6MCK1','1BPxymA3FSdUbfHTEzBycf5CsVbWqDGp6A',
	'1LoZdpsX9c662bKJTpt8cEfANmu8WRKKKN'
){
	my $script = CBitcoin::Script::address_to_script($addr);
	print "Bail out!" unless defined $script && 0 < length($script);
	$script = CBitcoin::Script::serialize_script($script);
	print "Bail out!" unless defined $script && 0 < length($script);
	push(@scripts,$script);
}
my @outpoints = (
	['5c60efa2d20a77fd3885148522e09ee4711b610b04947b91f67ec1d48ba1ec5e',1],
	['e44bebbea596c72b2a2d8d1b105fe54b74d791ffc161150bb2c18ac0bfed9a7b',0]
);

$block = CBitcoin::Block->deserialize_filtered(
	$msg->payload(),\@scripts,\@outpoints,1000,0.001
);
#warn "Tx By Hash=".Data::Dumper::Dumper($block->{'tx'})."\n";
ok(
	$block->{'success'}
	&& $block->tx_by_hash('6295b025647bdc5fd3c0fee5b635daf786cdf1ba06cd8d0fbdb46dbdf340dfbf')
	&& $block->tx_by_hash('4f3e834eb1d0ec1d2586a75ca6b2dd38e5da1b137fe422078af708a04791abed')
	, 'successful serialization of bloom filter'
);

#warn "Success=".$bhash->{'success'}."\n";
#warn "Bhash:".Data::Dumper::Dumper($bhash)."\n";
# test these addresses 
#$hash->{'data'} = '' unless defined $hash->{'data'};
#warn "Got BF=".unpack('H*',$hash->{'data'})."\n";


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
