use strict;
use warnings;

use CBitcoin ':network_bytes';
use CBitcoin::CBHD;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;

use Test::More tests => 1;

$CBitcoin::network_bytes = TESTNET;

my $root = CBitcoin::CBHD->generate("for doing a test. 60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d");



my @ins;
my @outs;
my @inputs;
my @outputs;
{
	@inputs = (
		{
			'hash' => '60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d'
			,'index' => 3
			,'script' => 'OP_DUP OP_HASH160 0x'.
				unpack('H*',$root->deriveChild(1,1)->{'ripemdHASH160'})
				.' OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.01032173*100000000
		}
		,{
			'hash' => '353082e37e57d2006517db8b6a75d905c49ae528cfff523a959a4fbf44203860'
			,'index' => 0
			,'script' => 'OP_DUP OP_HASH160 0x'.
				unpack('H*',$root->deriveChild(1,2)->{'ripemdHASH160'})
				.' OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.00119999*100000000		
		}
	);
	
	my $i = 1;
	foreach my $in (@inputs){
		my $address = CBitcoin::Script::script_to_address($in->{'script'});
		# warn "Address=".$root->deriveChild(1,$i)->address()."\n";
		$i++;
		push(@ins,CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',$in->{'hash'}) #should be 32 byte hash
			,'prevOutIndex' => $in->{'index'}
			,'script' => $in->{'script'} # scriptPubKey
		}));
		
		
	}
}

{
	@outputs = (
		{
			'address' => '198Lb2wtUEMzAAMdxBjqhGsUPG1RkKFUgh'
			,'script' => 'OP_DUP OP_HASH160 0x592444aa94e0d8a06442c73f2dc56c5c11de7c5b OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.010173*100_000_000
		}
		,{
			'address' => '1L9cXroh15fCoegiNqbsrxZg7wemc7a2r1'
			,'script' => 'OP_DUP OP_HASH160 0xd20b60d4a931079074d43c92fc4686dc37ac5f7b OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.010472*100_000_000
		}
	);
	foreach my $x (@outputs){
		push(@outs,CBitcoin::TransactionOutput->new($x));
	}
}



{
	# got these from a block explorer, but we have to reverse the bytes
	my @hashes = (
		'6105e342232a9e67e4fa4ee0651eb8efd146dc0d7d346c788f45d8ad591c4577',
		'da16a3ea5101e9f2ff975ec67a4ad85767dd306c27b94ef52500c26bc88af5c9'
	);
	
	@ins = (
		# mwUaFw3zQ8M4iaeuhFiiGWy4QbTphAeSxh 0.01394
		CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',join('',reverse($hashes[0] =~ m/([[:xdigit:]]{2})/g) )  ) #should be 32 byte hash
			,'prevOutIndex' => 1
			,'script' =>  CBitcoin::Script::address_to_script($root->deriveChild(1,1)->address()) # scriptPubKey
		}),
		# ms2Kt13CEL5jTMs98qXMAD15WpmnsK5ZGg 0.01408
		CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',join('',reverse($hashes[1] =~ m/([[:xdigit:]]{2})/g) ) ) #should be 32 byte hash
			,'prevOutIndex' => 1
			,'script' =>  CBitcoin::Script::address_to_script($root->deriveChild(1,2)->address()) # scriptPubKey
		})	
	);
	my $balance = int( (0.01394 + 0.01408) * 100_000_000);
	my $fee = int(0.0001 * 100_000_000);
	
	#warn "Address:".$root->export_xpriv()."\n";
	#warn "Address:".$root->deriveChild(1,1)->address()."\n";
	#warn "Address:".$root->deriveChild(1,2)->address()."\n";
	#warn "Address:".$root->deriveChild(1,3)->address()."\n";
	
	@outs = (CBitcoin::TransactionOutput->new({
		'script' => CBitcoin::Script::address_to_script($root->deriveChild(1,3)->address())
		,'value' => ($balance - $fee)
	}));
	
	# mi5W6CfThYwzTDsJg8Swu223dmyPPXDc8w
	# mi5W6CfThYwzTDsJg8Swu223dmyPPXDc8w
	
	my $tx = CBitcoin::Transaction->new({
		'inputs' => \@ins, 'outputs' => \@outs
	});
	
	my $txdata = $tx->assemble_p2pkh(0,$root->deriveChild(1,1));
	#warn "Txdata:".unpack('H*',$txdata)."\n";
	$txdata = $tx->assemble_p2pkh(1,$root->deriveChild(1,2),$txdata);
	
	#warn "TX:".unpack('H*',$txdata )."\n";
	ok($tx->validate_sigs($txdata),'good tx');
}




__END__

require CBitcoin::CBHD;
require CBitcoin::Script;
require CBitcoin::TransactionInput;
require CBitcoin::TransactionOutput;
require CBitcoin::Transaction;
require Data::Dumper;


# create 2 sigs
my $cbhd_alpha = CBitcoin::CBHD->new();
my $cbhd_beta = CBitcoin::CBHD->new();
$cbhd_alpha->generate();
$cbhd_beta->generate();

my $multisig_script = 'OP_2 0x'.
	$cbhd_alpha->publickey().' 0x'.
	$cbhd_beta->publickey().' OP_2 OP_CHECKMULTISIG';
warn "multsig script=$multisig_script\n";
my $multisig_address = CBitcoin::Script::script_to_address($multisig_script);

warn "Script=$multisig_script\naddress=$multisig_address\n";



my @inputs = (
	{
		'data' => '3045022100e2a8aeffa78232e897d11e620649ca800d858f727785a55bf4c3c75464d4c29d0220184a698d48e94da4d5fe52fd293cbea31231d61e9bece1c080a6f4e54bc38d4e01'
		,'hash' => '60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d'
		,'index' => 0
		,'address' => CBitcoin::Script::script_to_address($multisig_script)

		,'script' => CBitcoin::Script::address_to_script(
			CBitcoin::Script::script_to_address($multisig_script)
		) # use p2sh

		,'value' => 0.01032173*100000000
	}
	,{
		'data' => '304402204c2aa2c3f343dfa9acd45620e7485e8c7f00e2f67a5876f2ed1ab7dc6bc459af02207c065ef4bfa81b5fc3b98dd124a5a6cf84799034bd37e50ed848f298b96d915301'
		,'hash' => '353082e37e57d2006517db8b6a75d905c49ae528cfff523a959a4fbf44203860'
		,'index' => 0
		,'address' => $cbhd_alpha->address()
		,'script' => CBitcoin::Script::address_to_script($cbhd_alpha->address())
		,'value' => 0.00119999*100000000		
	}
);


my $txhash = 'a4e56cf47b0c853d5a9206b262b30bea5dc336926626558e9419e5769f326e07';
my @outputs = (
	{
		'address' => '1JfkgyctXCT1N7sWm3Bcf7oSp51fEcmta9'
		,'script' => 'OP_DUP OP_HASH160 0xc1ce6a3171f3ad0452070b7a5a52315b84a94951 OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01032173*100000000
	}
	,{
		#'address' => '1PwB5UYC1rL2Dsmsri68hhS4E8x6abwULP'
		#,'script' => 'OP_DUP OP_HASH160 0xfb91a42334c73c391ab6a81e337d51ce14ee22f7 OP_EQUALVERIFY OP_CHECKSIG'
		'address' => CBitcoin::Script::script_to_address($multisig_script)
		,'script' => $multisig_script
		,'value' => 0.01042172*100000000
	}
);





my $j = 0;
my @ins;

foreach my $in (@inputs){
	$j++;
	
	push(@ins,
		CBitcoin::TransactionInput->new({
			'prevOutHash' => $in->{'hash'}
			,'prevOutIndex' => $in->{'index'}
			,'script' => $in->{'script'}
		})
	);
}

#my $xo = Data::Dumper::Dumper(\@ins);
#warn "Ins=$xo\n";

my @outs;

foreach my $in (@outputs){
	$j++;
	#warn "Data:".$in->{'data'}."\n";
	

	push(@outs,
		CBitcoin::TransactionOutput->new({
			'value' => $in->{'value'}
			,'script' => $in->{'script'}
		})	
	);

}
#$xo = Data::Dumper::Dumper(\@outs);
#warn "Outs=$xo\n";

# create a transaction
my $tx = CBitcoin::Transaction->new({
	'inputs' => \@ins
	,'outputs' => \@outs
	,'p2sh' => 1 # means by default, change non-p2pkh scripts to p2sh
});


#$xo = Data::Dumper::Dumper($tx);
#warn "XO=$xo\n";



ok ( $tx->numOfInputs , 'Testing Tx: '.1) || print "Bail out!\n";

=pod

---++ Test Signing

Sign this transaction.

For p2sh, do the following:
   1. do multisig signatures
   1. Add the redeeming script to the end via:
   	CBTransactionAddP2SHScript(CBTransaction * self, CBScript * p2shScript, uint32_t input)


=cut




# $tx->sign_single_input($index,$cbhdkey)

=pod

The first input is 2 of 2 multisig key.

=cut

$tx->sign_single_input(0,$cbhd_alpha,'multisig');
$tx->sign_single_input(0,$cbhd_beta,'multisig');
warn "\n";
$tx->add_redeem_script(0,$multisig_script);

$tx->sign_single_input(1,$cbhd_alpha,'p2pkh');



warn "TX=".$tx->serialized_data()."\n";

ok($tx->serialized_data());


__END__


