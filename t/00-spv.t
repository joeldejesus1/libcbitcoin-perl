use strict;
use warnings;


use Test::More tests => 1;
use File::Slurp qw/read_file/;

ok(1,'nothing to test');

use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::Tree;
use CBitcoin::CLI::SPV;

$CBitcoin::network_bytes = CBitcoin::TESTNET;


{
	my $mfp = '/dev/mqueue';
	opendir(my $fh,$mfp);
	my @s = readdir($fh);
	closedir($fh);
	foreach my $x (@s){
		if($x =~ m/^(spv\.*)$/){
			unlink($mfp.'/'.$1);
		}
	}
}




my @spvpids;
for(my $i=0;$i<1;$i++){
	my $pid = fork();
	if(0 < $pid){
		# 	successful fork
		push(@spvpids,$pid);
	}
	elsif($pid == 0){
		sleep 2 if $i==1;
		
		# redirect output to log file
		open(STDOUT,'>','t/db1/spv.log');
		open(STDERR,'>','t/db1/spv.err.log');
		
		# testing: cbitcoin spv --address=127.0.0.1:8333 --node=gb5ypqt63du3wfhn.onion:8333 --watch=1BhT26zK7g9hXb3PDkwenkxpBeGYa6MCK1 --clientname="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/"
		CBitcoin::CLI::SPV::run_cli_args('spv',
			'--address=127.0.0.1:'.CBitcoin::SPV::DEFAULT_PORT,
			'--node=bitcoind.regtest:'.CBitcoin::SPV::DEFAULT_PORT,
			'--clientname="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/"',
			'--dbpath=t/db1'
		);	
	}
	else{
		warn "bad fork\n";
		print "Bail out!";
	}
}

# always daemonizes




my $pid2 = fork();

if(0 < $pid2){
	# successful fork
	push(@spvpids,$pid2);
}
elsif($pid2 == 0){
	CBitcoin::CLI::SPV::run_cli_args('read');
}
else{
	warn "bad fork\n";
	print "Bail out!";
}


warn "Sleeping for 5 seconds to give time to the spv process to start up.";
sleep 3;
CBitcoin::CLI::SPV::run_cli_args('cmd',
	'--node=122.10.95.70:'.CBitcoin::SPV::DEFAULT_PORT,'--node=103.208.86.32:'.CBitcoin::SPV::DEFAULT_PORT
);

{
	######## send a bloom filter ###########
	my ( $infh,$outfh);
	pipe( $outfh, $infh);
	
	my $bfpid = fork();
	if($bfpid == 0){
		close($infh);
		open( STDIN,'<&',$outfh) || die "Bail out! $!";
		CBitcoin::CLI::SPV::run_cli_args('spv','bloomfilter');		
		exit(0);
	}
	elsif($bfpid < 0){
		print "Bail out!";
		die "Bail out!";
	}
	
	my $xstring = File::Slurp::read_file( 't/secret' );
	
	my $xprv = CBitcoin::CBHD->new($xstring);
	
	my $tree = CBitcoin::Tree->new(	
		["ROOT/CHANNEL","ROOT/SERVERS/2/CHANNEL","ROOT/CASH"]
		,{'base directory' => 't/db1', 'id' => 'wallet'}
	);
	
	$tree->hdkey_set("ROOT",$xprv);
	$tree->max_i('+40');
	
	my $bfdata = $tree->bloomfilter->data;
	
	my ($m,$n) = (0,length($bfdata));
	$n //=0;
	unless(0 < $n){
		print "Bail out!";
		die "bad bfdata";
	}
	while(0 < $n - $m){
		$m += syswrite($infh,$bfdata,$n-$m,$m);
	}
	close($infh);
	
	sleep 5;
	kill('INT',$bfpid);
	sleep 3;
	kill('TERM',$bfpid);
	waitpid($bfpid,0);
}


sleep 10;

warn "Finished testing";
while(my $pid = shift(@spvpids)){
	kill('INT',$pid);
	waitpid($pid,0);
}


# remove mqueues once we are done
my $contents = `ls -la /dev/mqueue`;
print STDERR $contents."\n";
`rm /dev/mqueue/*`;


print "Bail out!";

__END__

