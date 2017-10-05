package CBitcoin::TransactionOutput;

use strict;
use warnings;

=head1 NAME

CBitcoin::TransactionOutput - The great new CBitcoin::TransactionOutput!

=cut

use CBitcoin;
use CBitcoin::Script;
use CBitcoin::Utilities;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::TransactionOutput::VERSION = $CBitcoin::VERSION;

DynaLoader::bootstrap CBitcoin::TransactionOutput $CBitcoin::VERSION;

@CBitcoin::TransactionOutput::EXPORT = ();
@CBitcoin::TransactionOutput::EXPORT_OK = ();


=item dl_load_flags

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

=pod

---++ new()

=cut

sub new {
	my $package = shift;
	my $this = bless({}, $package);

	my $x = shift;
	unless(ref($x) eq 'HASH'){
		return $this;
	}
	if(
		defined $x->{'value'} && $x->{'value'} =~ m/^[0-9]+$/
		&& defined $x->{'script'} && 0 < length($x->{'script'})
	){
		# call this function to validate the data, and get serialized data back
		# this is a C function
		$this->{'value'} = $x->{'value'};
		$this->{'script'} = $x->{'script'};
	}
	elsif(
		defined $x->{'value'} && $x->{'value'} =~ m/^([0-9]+)$/
	){
		#warn "empty script\n";
		$this->{'value'} = $x->{'value'};
		$this->{'script'} = '';
	}
	else{
		#require Data::Dumper;
		#warn "options=".Data::Dumper::Dumper($x);
		die "no arguments to create Transaction::Output";
	}
		
	return $this;
}



=pod

---++ script

=cut

sub script {
	return shift->{'script'};
}

=pod

---++ type_of_script

=cut

sub type_of_script {
	my $this = shift;
	return CBitcoin::Script::whatTypeOfScript( 
		CBitcoin::Script::deserialize_script($this->script)
	);
}

=pod

---++ value

=cut

sub value {
	return shift->{'value'};
}

=pod

---+ i/o

=cut

=pod

---++ serialize

=cut

sub serialize {
	my ($this) = @_;

	my $script = CBitcoin::Script::serialize_script($this->script);
	die "bad script" unless defined $script;
	
	return pack('q',$this->value).CBitcoin::Utilities::serialize_varint(length($script)).$script;
}

=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-transactionoutput at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::TransactionOutput


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=libperl-cbitcoin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/libperl-cbitcoin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/libperl-cbitcoin>

=item * Search CPAN

L<http://search.cpan.org/dist/libperl-cbitcoin/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::TransactionOutput
