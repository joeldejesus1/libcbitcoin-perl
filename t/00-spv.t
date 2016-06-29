use strict;
use warnings;


use Test::More tests => 1;


ok(1,'nothing to test');

use CBitcoin;
use CBitcoin::CLI::SPV;


# always daemonizes
my $pid = fork();

if(0 < $pid){
	warn "Sleeping for 5 seconds to give time to the spv process to start up.";
	sleep 5;
	CBitcoin::CLI::SPV::run_cli_args('cmd',
		'--node=q6m5jhenk33wm4j4.onion:8333','--node=l4xfmcziytzeehcz.onion:8333'
	);
	
	sleep 5;
	
	warn "Finished testing";
	kill('KILL',$pid);
	waitpid($pid,0);
}
elsif($pid == 0){
	CBitcoin::CLI::SPV::run_cli_args('spv',
		'--address=127.0.0.1:8333',
		'--node=gb5ypqt63du3wfhn.onion:8333',
		'--watch=1BhT26zK7g9hXb3PDkwenkxpBeGYa6MCK1',
		'--clientname="/BitcoinJ:0.2(iPad; U; CPU OS 3_2_1)/AndroidBuild:0.8/"'
	);	
}
else{
	warn "bad fork\n";
	print "Bail out!";
}



__END__

