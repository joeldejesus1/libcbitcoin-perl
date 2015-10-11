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
