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
use Digest::SHA;

use constant MAINNET    => 0xd9b4bef9, TESTNET => pack('L',0xdab5bffa), TESTNET3 => pack('L',0x0709110b), NAMECOIN => pack('L',0xfeb4bef9) ;

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



=pod

---+ Objects


=cut

sub new {
	my $package = shift;
	
	my $options = shift;
	
	my $this = {
		'command' => $options->{'command'},
		'magic' => $options->{'magic'},
		'payload' => $options->{'payload'}
	};
	bless($this,$package);
	# do some checks
	#..length
	if(length($this->payload) != unpack('L',$options->{'length'})  ){
		die "message payload is of the wrong length";
	}
	
	if(substr(checksum_payload($this->payload),0,4) ne $options->{'checksum'}  ){
		die "message payload checksum failed";
	}	
	

	return $this;
}

=pod

---+ Getters/Setters

=cut

sub payload {
	return shift->{'payload'};
}

sub magic {
	return shift->{'magic'};
}

sub command {
	return deserialize_command(shift->{'command'});
}


=pod

---+ Subroutines


=cut






=pod

---++ net_magic

Are we on mainnet, testnet or namecoin?

=cut


sub net_magic {
	my $x = shift;
	$x = 'MAINNET' unless defined $x; # did this to avoid warnings about inititialized values
	my $netmapper = {'MAINNET' => 0xd9b4bef9, 'TESTNET' => 0xdab5bffa,'TESTNET3' => 0x0709110b,'NAMECOIN' => 0xfeb4bef9};
	return $netmapper->{$x} if defined $netmapper->{$x};
	return $netmapper->{'MAINNET'};
}


=pod

---++ serialize($payload,$command,$magic)

main 0xd9b4bef9
testnet, 0xdab5bffa
testnet3, 0x0709110b
namecoin, 0xfeb4bef9


=cut



sub serialize {
	my $payload = shift;
	my $command = shift;
	my $magic = shift;
	$magic = pack('L',net_magic($magic));
	
	
	#die "payload is 0" unless length($payload) > 0;
	#warn "Magic=".unpack('H*',$magic)."\n";
	#warn "Command=".unpack('H*',serialize_command($command))."\n";
	#warn "Length=".unpack('H*',pack('L',length($payload)))."\n";
	#warn "Checksum=".unpack('H*',substr(checksum_payload($payload),0,4))."\n";
	return $magic.serialize_command($command).pack('L',length($payload)).substr(checksum_payload($payload),0,4).$payload;
	
}

sub checksum_payload {
	my $payload = shift;
	if(length($payload) > 0){
		return Digest::SHA::sha256(Digest::SHA::sha256($payload));
	}
	else{
		return pack('L',0xe2e0f65d);
	}
}


sub serialize_command{
	my $command = shift;
	die "command is too short" unless defined $command && length($command) > 0;
	die "command is too long" unless length($command) <= 12;
	my @ASCII = unpack("C*", $command);	

	my @bin;
	foreach my $i (0..11){
		$bin[$i] = pack('C',$ASCII[$i]) unless $i >= scalar(@ASCII);
		if($i < scalar(@ASCII)){
			$bin[$i] = pack('C',$ASCII[$i]);
		}
		else{
			$bin[$i] = pack('x');
		}
	}
	return join('',@bin);
}

sub deserialize_command {
	my $command = shift;
	$command =~ tr/\0//d;
	return $command
}


sub read_message {
	my $fh = shift;
	
	# ignore blocks
	
		
}









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
