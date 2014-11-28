package CBitcoin;

#use 5.006;
use strict;
use warnings;

=head1 NAME

CBitcoin - The great new CBitcoin!

=head1 VERSION

Version 0.01

=cut

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::VERSION = '0.01';

#DynaLoader::bootstrap CBitcoin $CBitcoin::VERSION;

@CBitcoin::EXPORT = ();
@CBitcoin::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=item hello

just a place holder.

=cut

sub hello {
	return "hello!";
}



=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libcbitcoin-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libcbitcoin-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=libcbitcoin-perl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/libcbitcoin-perl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/libcbitcoin-perl>

=item * Search CPAN

L<http://search.cpan.org/dist/libcbitcoin-perl/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin
