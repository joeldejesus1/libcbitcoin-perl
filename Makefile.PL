#use 5.014002;
use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker;
use Cwd 'cwd';


my $cwd = cwd;
my %opts;
@ARGV = map { /^CBitcoin_(\w+)=(.*)/ ? do { $opts{lc $1} = $2; (); } : $_ } @ARGV
if @ARGV;

my %XS = qw(
	lib/CBitcoin.xs        lib/CBitcoin.c
	lib/CBitcoin/Transaction.xs   lib/CBitcoin/Transaction.c
	lib/CBitcoin/TransactionOutput.xs   lib/CBitcoin/TransactionOutput.c
	lib/CBitcoin/TransactionInput.xs   lib/CBitcoin/TransactionInput.c
	lib/CBitcoin/Script.xs   lib/CBitcoin/Script.c
	lib/CBitcoin/CBHD.xs   lib/CBitcoin/CBHD.c
	lib/CBitcoin/Block.xs   lib/CBitcoin/Block.c
);
my @OBJECT = values %XS;

for (@OBJECT)
{
    s/\.c\b/\$(OBJ_EXT)/g;
}

my $OBJECT = join(' ', @OBJECT);

#warn "OBJECT=$OBJECT\n";

my $from;
my %PM = map { ($from = $_) =~ s/xs$/pm/;
($from, "\$(INST_LIBDIR)/$from"); } (keys %XS);

my $CLEAN = join(' ', values %XS) . " $OBJECT";



WriteMakefile(
	    'TYPEMAPS' => []
	    ,'NAME' => 'CBitcoin'
	     ,'LIBS' => [ ' -lcrypto -lccoin -lgmp ' ]
		,'VERSION' => '0.3'

		,'AUTHOR'              => q{Joel DeJesus (Work Email) <dejesus.joel@e-flamingo.jp>}
		,'VERSION_FROM'        => 'lib/CBitcoin.pm'
#		,'OBJECT'              => q/$(O_FILES)/
		,'PM'           => \%PM
		,'XS' => \%XS
		,'OBJECT' => $OBJECT
		#,'MYEXTLIB' => '/usr/lib/libcbitcoin.so.1'
	,($ExtUtils::MakeMaker::VERSION >= 6.3002
	      ? ('LICENSE'=> 'gpl_2')
	      : ())
	,'PL_FILES'            => {}
	,'PREREQ_PM' => {
		'Test::More' => 0,
		'BerkeleyDB' => 0
	}
	,'EXE_FILES' => [
		'scripts/cbitcoin'	
	]
	#,'LDDLFLAGS' => ' -fstack-protector '
	#,'LDFLAGS' => ' -fstack-protector '
	,'MAKEFILE_OLD' => ''
	,'dist'                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', }
	#,'clean'               => { FILES => 'libcbitcoin-perl*' }
	,'clean'               => { FILES => 't/db1 lib/*.o lib/CBitcoin/*.o' }
);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile {
	return qq{
};

}

sub MY::c_o
{
    package MY; # so that "SUPER" works right

    my $text = shift->SUPER::c_o(@_);

    $text =~ s/CCCMD.*$/$& -o \$*\$(OBJ_EXT)/gm;

    $text;
}

sub MY::postamble
{
	my $self = shift;
	return;
	my @text;
	
    # Create per-object-file dependancy on RPM.h
    push(@text, ('',
                 (map { "$_: CBitcoin.h\n" } @OBJECT),
                 ''));

	join("\n", @text);
}

__END__

    Copyright (C) 2015  Joel De Jesus

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
