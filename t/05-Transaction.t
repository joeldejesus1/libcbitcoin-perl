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

sub test1{
	my $json_data = '';
	open(my $fh,'<','t/tx_valid.json');
	while(<$fh>){ $json_data .= $_; }
	close($fh);
	
	$json_data = JSON::XS::decode_json($json_data);
	
	require Data::Dumper;
	#warn "data=".Data::Dumper::Dumper($json_data);
	# format: "[[[prevout hash, prevout index, prevout scriptPubKey], [input 2], ...],"
	
	while(my $row = shift(@{$json_data})){
		if(scalar(@{$row}) == 1){
			#warn $row->[0]."\n";
			next;
		}
		# [\@inputs,"serializedTransaction, verifyFlags]"
		my @inputs;
		my @script_pubs;  my @amounts;
		while(my $in = shift(@{$row->[0]})){
			# prevout hash, prevout index, prevout scriptPubKey
			my $scriptpub = $in->[2];
			#warn "pre-regex sp=$scriptpub\n";
			$scriptpub =~ s/[\s\t　]+/ /g;
			my @y = split(/\s/,$scriptpub);
			my @x;
			#warn "scriptpub - 0 p[".scalar(@y)."]\n";
			while(defined(my $z = shift(@y))){
				#warn "got z=$z";
				if($z =~ m/^OP_(.*)$/){
					#warn "pushing $1";
					push(@x,'ccoin_OP_'.$1);
				}
				elsif($z =~ m/^(\d+)$/){
					#warn "pushing $1";
					push(@x,'ccoin_OP_'.$1);
				}
				elsif($z =~ m/^[A-Z]/){
					#warn "pushing $z";
					push(@x,'ccoin_OP_'.$z);
				}
				else{
					#warn "pushing $z";
					push(@x,$z);
				}
			}
			#warn "scriptpub - 1 p=".join('|',@x)."\n";
			die "no script pub" unless 0 < length(join('|',@x));
			$scriptpub = CBitcoin::Script::convert_CCOIN_to_OP(@x);
			push(@script_pubs,$scriptpub);
			push(@amounts,0);
			#warn "p - 2\n";
			push(@inputs,CBitcoin::TransactionInput->new({
				'prevOutHash' => pack('H*',$in->[0]) #should be 32 byte hash
				,'prevOutIndex' => $in->[1]
				,'script' => $scriptpub # scriptPubKey
				,'input_amount' => 0
			}));
			
			
		}
		
		#warn "p - 3\n";
		#warn "tx=".$row->[1]."\n";
		my $rawtx = pack('H*',$row->[1]);
		my $flags = 0;
		my @f = split(',',$row->[2]);
		my $fmap = $CBitcoin::Transaction::flagmap;
		while(my $f1 = shift(@f)){
			$flags = $flags | $fmap->{$f1};
		}
		
		
		
		my $tx = CBitcoin::Transaction->deserialize($rawtx,\@script_pubs,\@amounts);
		die "no tx" unless defined $tx;
		#warn "script pub\n";
		for(my $i=0;$i<$tx->numOfInputs();$i++){
			next;
			#warn "..script pub[$i]=".$script_pubs[$i]."\n";
			$tx->input($i)->script($script_pubs[$i]);
			my $bool = CBitcoin::Transaction::picocoin_tx_validate_input(
					$i
					, CBitcoin::Script::serialize_script($tx->input($i)->script()) # scriptPubKey
					, $rawtx  # includes scriptSig
					, $flags # sigvalidate
					, 0 # default;
					, pack('q',$tx->input($i)->input_amount())
				);
			#warn "bool=$bool\n";
			unless($bool){
				#warn "script on bad=".$tx->input($i)->script()."\n";
			}
			
			
			#ok(  
			#	$bool				
			#	,'tx input'
			#)
		}
		
		#ok($tx->validate_sigs($rawtx,$flags),'good tx with flags='.$flags);
		

		
		#last;
	}
}

test1();


my $root = CBitcoin::CBHD->generate("for doing a test. 60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d");



my @ins;
my @outs;
my @inputs;
my @outputs;
sub test2{
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
test2();

sub test3{
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
test3();


sub test4{
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
	ok($tx->validate_sigs($txdata),'good tx on signed tx');
	#ok(1,'good tx (validate sigs not yet implemented)');
}
test4();

sub test_uahf{
	# TESTING UAHF
	$CBitcoin::chain = CBitcoin::CHAIN_UAHF;
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
		'inputs' => \@ins, 'outputs' => \@outs
	});
	#warn "p2pkh - 1\n";
	my $txdata = $tx->assemble_p2pkh(0,$root->deriveChild(1,1));
	
	#warn "p2pkh - 2\n";
	#warn "Txdata:".unpack('H*',$txdata)."\n";
	$txdata = $tx->assemble_p2pkh(1,$root->deriveChild(1,2),$txdata);
	
	#warn "TX:".unpack('H*',$txdata )."\n";
	#warn "validate sigs\n";
	ok($tx->validate_sigs($txdata),'good tx with uahf');
}
test_uahf();


__END__


