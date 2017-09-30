use strict;
use warnings;

use CBitcoin ;
use CBitcoin::CBHD;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;

use JSON::XS;
use Test::More tests => 2;

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
				unpack('H*',$root->deriveChild(1,1)->ripemdHASH160)
				.' OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.01032173*100000000
		}
		,{
			'hash' => '353082e37e57d2006517db8b6a75d905c49ae528cfff523a959a4fbf44203860'
			,'index' => 0
			,'script' => 'OP_DUP OP_HASH160 0x'.
				unpack('H*',$root->deriveChild(1,2)->ripemdHASH160)
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

{
	# TESTING UAHF
	
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
			,'input_amount' => int(0.01394 * 100_000_000)
		}),
		# ms2Kt13CEL5jTMs98qXMAD15WpmnsK5ZGg 0.01408
		CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',join('',reverse($hashes[1] =~ m/([[:xdigit:]]{2})/g) ) ) #should be 32 byte hash
			,'prevOutIndex' => 1
			,'script' =>  CBitcoin::Script::address_to_script($root->deriveChild(1,2)->address()) # scriptPubKey
			,'input_amount' => int(0.01408 * 100_000_000)
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
		'inputs' => \@ins, 'outputs' => \@outs, 'chain_type' => 'uahf'
	});
	
	my $txdata = $tx->assemble_p2pkh(0,$root->deriveChild(1,1));
	#warn "Txdata:".unpack('H*',$txdata)."\n";
	$txdata = $tx->assemble_p2pkh(1,$root->deriveChild(1,2),$txdata);
	
	#warn "TX:".unpack('H*',$txdata )."\n";
	ok($tx->validate_sigs($txdata),'good tx with uahf');
}



__END__


