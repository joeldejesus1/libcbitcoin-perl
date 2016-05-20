use strict;
use warnings;

use JSON::XS;
use Data::Dumper;

use Test::More tests => 469;

require CBitcoin::Script;

my $tests;


#...........................................
{
	
	open(my $fh,'<','t/scripts-valid.json') || print "Bail out!";
	my $jsontxt = '';
	while(<$fh>){
		#warn "JSON:$jsontxt";
		$jsontxt .= $_;
	}
	close($fh);
	my $tests = JSON::XS::decode_json($jsontxt);
	foreach my $test (@{$tests}){
		my ($x,$script) = @{$test};
		my @sarray;
		foreach my $s (split(' ',$script)){
			if($s !~ m/^(\d|\'|\-|NOP)/ ){
				push(@sarray,'OP_'.$s);
			}
			else{
				push(@sarray,$s);
			}
		}
		
		my $serialized_script = CBitcoin::Script::picocoin_script_decode(
			CBitcoin::Script::convert_OP_to_CCOIN(join(' ',@sarray))
		);
		unless(defined $serialized_script){
			$serialized_script = '' unless defined $serialized_script;
		}
		
		ok(0 < length($serialized_script),'Failed at script '.join(' ',@sarray));
		#warn "Script:".unpack('H*',$serialized_script)."\n";
	}
	
}

{
	
	open(my $fh,'<','t/scripts-invalid.json') || print "Bail out!";
	my $jsontxt = '';
	while(<$fh>){
		#warn "JSON:$jsontxt";
		$jsontxt .= $_;
	}
	close($fh);
	my $tests = JSON::XS::decode_json($jsontxt);
	foreach my $test (@{$tests}){
		my ($x,$script) = @{$test};
		my @sarray;
		foreach my $s (split(' ',$script)){
			if($s !~ m/^(\d|\'|\-|NOP)/ ){
				push(@sarray,'OP_'.$s);
			}
			else{
				push(@sarray,$s);
			}
		}
		
		my $serialized_script = CBitcoin::Script::picocoin_script_decode(
			CBitcoin::Script::convert_OP_to_CCOIN(join(' ',@sarray))
		);
		unless(defined $serialized_script){
			$serialized_script = '' unless defined $serialized_script;
		}
		
		ok(0 < length($serialized_script),'Failed at script '.join(' ',@sarray));
		#warn "Script:".unpack('H*',$serialized_script)."\n";
	}
	
}




{
	my $script = 'OP_DUP OP_HASH160 0x592444aa94e0d8a06442c73f2dc56c5c11de7c5b OP_EQUALVERIFY OP_CHECKSIG';
	#warn "Script:[$script]\n";
	my $serialized_script = CBitcoin::Script::picocoin_script_decode(
		CBitcoin::Script::convert_OP_to_CCOIN($script,1)
	);
	
	#warn "Serialized:".unpack('H*',$serialized_script)."\n";
	my $x = CBitcoin::Script::picocoin_parse_script($serialized_script);
	if(defined $x && ref($x) eq 'ARRAY' && $x->[-1] == 1){
		delete $x->[-1];
		#warn "XO:".Data::Dumper::Dumper($x)."\n";
		$x = CBitcoin::Script::convert_CCOIN_to_OP(@{$x});
		#warn "X:[$x]\n";
		chomp($x);
		
	}
	else{
		$x = '';
	}
	
	ok($script eq $x,'encode and decode script');
}


{
	my $address = '3DS7Y6bdePdnFCoXqddkevovh4s5M8NhgM';

	my $script = CBitcoin::Script::address_to_script($address);
	
	ok(
		defined $script
		&&  CBitcoin::Script::script_to_address($script) eq $address
		, 'test p2sh address'
	);	
	

}


{
	my $address = '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2';
	my $script = CBitcoin::Script::address_to_script($address); 
	ok(
		defined $script
		&&  CBitcoin::Script::script_to_address($script) eq $address
		, 'test p2pkh address'
	);
}

__END__
