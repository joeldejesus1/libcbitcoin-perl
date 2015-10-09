use 5.014002;
use strict;
use warnings;

use CBitcoin::Message;

use Test::More tests => 1;

my $x = CBitcoin::Message::testmsg(33);
require Data::Dumper;
my $xo = Data::Dumper::Dumper($x);

warn "X=$xo\n";

ok(1) || print "Bail out!";
