# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.3 1997/03/04 09:22:36 gbarr Exp $

#--- Distribution section ---

$NAME     = 'Mail';
$DISTNAME = "MailTools";
$VERSION  = "1.11";

BEGIN { require 5.001 }

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

#--- MY package

sub MY::libscan
{
 my($self,$path) = @_;

 return '' 
	if($path =~ m:/(RCS|CVS|SCCS)/: ||
	   $path =~ m:[~%]$: ||
	   $path =~ m:\.(orig|rej|nfs)$:
	  );
 return ''
	if $] < 5.004 and $path =~ m:/Mail/Field:;
 $path;
}

#--- Installation check

sub chk_version
{
 my($pkg,$wanted,$msg) = @_;

 $| = 1;
 print "Checking for $pkg...";

 eval { my $p; ($p = $pkg . ".pm") =~ s#::#/#g; require $p; };

 my $vstr = ${"${pkg}::VERSION"} ? "found v" . ${"${pkg}::VERSION"}
				 : "not found";
 my $vnum = ${"${pkg}::VERSION"} || 0;

 print $vnum >= $wanted ? "ok\n" : " " . $vstr . "\n";

 $vnum >= $wanted;
}

#--- Check for Socket

chk_version(Net::SMTP => 1.03) or
    warn  "\n"
	. "It is reccomended that you have Net::SMTP version 1.03 or later\n"
	. "Look on CPAN for CPAN/modules/by-author/id/GBARR/libnet-x.x.tar.gz\n\n";

chk_version(Net::Domain => 1.05) or
    warn  "\n"
	. "It is reccomended that you have Net::Domain version 1.05 or later\n"
	. "Look on CPAN for CPAN/modules/by-author/id/GBARR/libnet-x.x.tar.gz\n\n";

chk_version(IO::Handle => 0.00) or
    warn  "\n"
	. "To be able to use Mail::Mailer and Mail::Send you will need to\n"
	. "install the IO distribution.\n"
	. "Look on CPAN for CPAN/modules/by-author/id/GBARR/IO-x.x.tar.gz\n\n";

warn "\n"
   . "Mail::Field will not be installed as it requires perl 5.004 or later\n"
   . "and you only have $]\n\n"
	if $] < 5.004;

#--- Write the Makefile

my @clean = qw(*% *.html *.b[ac]k *.old);

push @clean, map { "*/$_" } @clean;

WriteMakefile(
	VERSION   => $VERSION,
	DISTNAME  => $DISTNAME,
	NAME      => $NAME,
 
	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => '.gz', 
		      DIST_DEFAULT => 'all tardist',
		     },
 
	'clean'   => {FILES => join(" ", @clean)},
);

