use strict;
use warnings;


use Test::More tests => 1;
use File::Slurp qw/read_file/;


use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::Block;
use CBitcoin::Tree;
use CBitcoin::CLI::SPV;
use CBitcoin::Utilities;

$CBitcoin::network_bytes = CBitcoin::REGNET;

$ENV{'RETURNSPV'} = 1;

my $bf;
{
	my $root = CBitcoin::CBHD->new("tprv8ZgxMBicQKsPfAewoUg9THau9Dwz9XihsxbNWTHx1rsBtu9Dn5HEmnaosQKiAfoDFBLW3UNbeNqS996pWQnW2zRnh3hStfXqKdiB313WVSn");
	my $tree = CBitcoin::Tree->new(	
		["ROOT/CHANNEL","ROOT/SERVERS/2/CHANNEL","ROOT/CASH"]
		,{'base directory' => 't/db1', 'id' => 'wallet'}
	);
	$tree->hdkey_set("ROOT",$root);
	
	$tree->max_i('+10');
	
	
	for(my $i=0;$i<20;$i++){
		my $hdkey = $tree->deposit_node("ROOT/CASH");
		warn "(i=$i) ".$hdkey->address().":".unpack('H*',$hdkey->publickey)."\n";
	}
	
	#$tree->bloomfilter_calculate();
	
	#$bf = $tree->bloomfilter();
}

ok(0,'dozer');

print "Bail out!";

__END__

my $spv = CBitcoin::CLI::SPV::run_cli_args('spv',
	'--address=127.0.0.1:'.CBitcoin::Utilities::DEFAULT_PORT,
	'--node=172.20.0.5:'.CBitcoin::Utilities::DEFAULT_PORT,
	'--clientname="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/"',
	'--dbpath=t/db1'
);

$spv->add_bloom_filter($bf,0);

$spv->loop();

print "Bail out!";

ok(1,'nothing to test');


__END__

warn "hi 1";
my $block = CBitcoin::Block->genesis_block();
warn "hi 2";
warn "prev hash=".$block->prevBlockHash_hex()."\n";
warn "hash=".$block->hash_hex()."\n";

warn "data=".unpack('H*',$block->data)."\n";

print "Bail out!";


