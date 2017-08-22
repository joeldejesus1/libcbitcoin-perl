use strict;
use warnings;


use Test::More tests => 1;
use File::Slurp qw/read_file/;

ok(1,'nothing to test');

use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::Tree;
use CBitcoin::CLI::SPV;
use CBitcoin::Utilities;

$CBitcoin::network_bytes = CBitcoin::REGNET;

CBitcoin::CLI::SPV::run_cli_args('spv',
	'--address=127.0.0.1:'.CBitcoin::Utilities::DEFAULT_PORT,
	'--node=172.20.0.5:'.CBitcoin::Utilities::DEFAULT_PORT,
	'--clientname="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/"',
	'--dbpath=t/db1'
);

print "Bail out!";

__END__

