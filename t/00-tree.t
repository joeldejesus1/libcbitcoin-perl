use strict;
use warnings;

use CBitcoin::Tree;
use CBitcoin::Tree::Broadcast;

use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;

use File::Slurp;

use Data::Dumper;

use Test::More tests => 10;

=pod

---+ Build Tree

Build out the default tree and set the root of the tree with the super secret xprv CBHD key.

=cut


my $xstring = File::Slurp::read_file( '.secret' );
my $xprv = CBitcoin::CBHD->new($xstring);
die "no xprv" unless defined $xprv;

$CBitcoin::network_bytes = CBitcoin::TESTNET;

my @block_times = (1476017968-5*60*60,1476017968-2*60*60,1476017968-1*60*60,1476017968);


unlink('db1');

my $tree = CBitcoin::Tree->new(	
	["ROOT/CHANNEL","ROOT/SERVERS/2/CHANNEL","ROOT/CASH"]
	,{'base directory' => 'db1', 'id' => 'wallet'}
);

$tree->hdkey_set("ROOT",$xprv);
$tree->max_i('+40');

{
	# check the deposit address
	
	ok('n1KKWuBaKw3akvUbWaYdoRYmU1receRGGT' eq $tree->deposit("ROOT/CASH"), 'Got correct deposit');
	
}


{
	# Got 0.301 sent to n1KKWuBaKw3akvUbWaYdoRYmU1receRGGT
	# scan the transaction
	my $txdata = pack('H*',File::Slurp::read_file( '.data/tx1' ));
	#warn "hi with txdata=".length($txdata);
	
	
	$tree->tx_add($block_times[0],$txdata);
	
	ok($tree->balance() == 30100000,'positive balance');
	
}


{
	# move money from ROOT/CASH to ROOT/CHANNEL
	
	my $serializedtx = $tree->cash_move("ROOT/CASH","ROOT/CHANNEL",10102039);
	
	# broadcast $serializedtx out on the network, eventually download it back via block
	
	ok($tree->balance() == 0,'No bitcoins available.');
	ok($tree->balance('inflight') == 30100000 ,'All bitcoins are outbound.');
	
}

{
	# register the transaction created above as if it came in off the peer to peer network
	my $txdata = pack('H*',File::Slurp::read_file( '.data/tx2' ));
	$tree->tx_add($block_times[1],$txdata);
	
	ok(20000000 < $tree->balance && $tree->balance < 30100000, 'new balance recognized');
	ok($tree->balance('inflight') == 0, 'inflight balance is 0');
	
	ok($tree->node_get_by_path('ROOT/CHANNEL')->balance == 10102039, 'ROOT/CHANNEL has correct balance');
}


{
	# check Broadcast scripting
	my $channel = $tree->node_get_by_path("ROOT/SERVERS/2/CHANNEL")->hdkey->ripemdHASH160;
	$channel = unpack('H*',$channel);
	
	my $uuid = '123e4567-e89b-12d3-a456-426655440000';
	
	my $rights = join('|','READMETA','WRITEMETA');
	
	
	# BR_SERVER [$ripemd, 20B] [$uuid, 16B] [$RightsBitField, 4B]
	my $msg = CBitcoin::Tree::Broadcast::serialize("BR_SERVER $channel $uuid $rights");
	ok(defined $msg && unpack('H*',$msg) eq '01324dd9d96c7d90ea0a84cac785937daee99bb0f5123e4567e89b12d3a4564266554400000300', 'parsed message');
	
	# create BROADCAST
	# check example: https://live.blockcypher.com/btc-testnet/tx/7ec5ee73c51618efd86eecf19ea357ad14047aae218f87c16881e44f5a672654/
	my $txdata = $tree->broadcast_send("ROOT/CHANNEL","BR_SERVER $channel $uuid $rights");
	
	ok(defined $txdata && 0 < length($txdata),'can broadcast');
	
	
}

{
	my $check_broadcast = 'BR_SERVER 324dd9d96c7d90ea0a84cac785937daee99bb0f5 123e4567e89b12d3a456426655440000 READMETA|WRITEMETA';
	
	# to receive broadcast, add callback
	my $node = $tree->node_get_by_path("ROOT/CHANNEL");
	
	
	my $m1 = '';
	$node->broadcast_callback(sub{
		my ($this,$message) = @_;
		my $m2 = \$m1;
		$$m2 = $message;
 	});
	
	# receive a broadcast
	my $txdata = pack('H*',File::Slurp::read_file( '.data/tx3' ));
	$tree->tx_add($block_times[2],$txdata);
	
	
	
	ok($check_broadcast eq $m1,'Got broadcast on correct channel');
}




__END__


