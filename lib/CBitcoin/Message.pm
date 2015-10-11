package CBitcoin::Message;

use 5.014002;
use strict;
use warnings;

=head1 NAME

CBitcoin::Message

=head1 VERSION

Version 0.01

=cut

use Net::IP;

use bigint;
use CBitcoin::Script;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Message::VERSION = '0.01';

DynaLoader::bootstrap CBitcoin::Message $CBitcoin::Message::VERSION;

@CBitcoin::Message::EXPORT = ();
@CBitcoin::Message::EXPORT_OK = ();

=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=item new

---++ new()

=cut

sub new {
	use bigint;
	my $package = shift;
	my $this = bless({}, $package);

	return $this;
}


=pod

---++ create_version($addr_recv_ip,$addr_recv_port)

$addr_recv is of the format: cidr:port

=cut

sub create_version{
	my ($addr_recv_ip,$addr_recv_port) = (shift,shift);
	return getversion1(ip_convert_to_binary($addr_recv_ip),$addr_recv_port);
}


=pod

---++ ip_convert_to_binary($string)

Convert AAA.BBB.CCC.DDD to network byte notation

=cut

sub ip_convert_to_binary {
	my($string) = (shift);
	my $ip  = Net::IP->new($string);
	if($ip->hexip() < 12){
		# set it so it goes in as an ipv6, cuz bitcoin mandates
		warn "this is an ipv4 with full=".unpack('H*',pack('B*',$ip->binip()))."\n";
		return pack('H*','00000000000000000000ffff'.unpack('H*',pack('B*',$ip->binip())));
	}
	else{
		return pack('H*',unpack('H*',pack('B*',$ip->binip())));
	}	
}


=pod

---++ ip_convert_to_string

=cut

sub ip_convert_to_string {
	my $binipv6 = shift;
	
	my $stripv6 = unpack('H*',$binipv6);
	
	if(substr($stripv6,0,24) eq '00000000000000000000ffff'){
		warn "ipv4 with full=$stripv6\n";
		return hex2ip(substr($stripv6,24,8));
	}
	else{
		warn "ipv6\n";
		return $stripv6;
	}
}

# helper function
sub hex2ip { return join(".", map {hex($_)} unpack('A2 A2 A2 A2',shift)) }


=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::Transaction
