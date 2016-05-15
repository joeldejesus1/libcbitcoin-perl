use strict;
use warnings;


use CBitcoin ':network_bytes';
use Test::More tests => 1;

require CBitcoin::Script;
require CBitcoin::TransactionOutput;


my $txhash = 'a4e56cf47b0c853d5a9206b262b30bea5dc336926626558e9419e5769f326e07';
my @outputs = (
	{
		'address' => '198Lb2wtUEMzAAMdxBjqhGsUPG1RkKFUgh'
		,'script' => 'OP_DUP OP_HASH160 0x592444aa94e0d8a06442c73f2dc56c5c11de7c5b OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01032173*100000000
	}
	,{
		'address' => '1L9cXroh15fCoegiNqbsrxZg7wemc7a2r1'
		,'script' => 'OP_DUP OP_HASH160 0xd20b60d4a931079074d43c92fc4686dc37ac5f7b OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01042172*100000000
	}
);

ok(1,'hello');

my $j = 0;
foreach my $in (@outputs){
	$j++;
	#warn "Data:".$in->{'data'}."\n";
	
	my $t_out = CBitcoin::TransactionOutput->new({
		'value' => $in->{'value'}
		,'script' => CBitcoin::Script::serialize_script($in->{'script'})
	});

}




