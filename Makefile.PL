# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.4 1995/11/21 08:47:51 gbarr Exp $

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

#--- Configuration section ---

#--- End User Configuration - You should not have to change anything below this line

require 5.001;

$VERSION  = "1.04";
$NAME     = 'Mail';
$DISTNAME = 'MailTools';

%chk_install =  (Net::SMTP   => [1.03, 0],
		 Net::Domain => [1.05, 0]
		);

#--- End Configuration

sub check_installation {
 my %pkg = @_;
 my $abort = 0;
 my $pkg;

 print "Checking your installation ...\n";

 foreach $pkg (keys %pkg) 
  {
   { eval "package dummy; require $pkg"; }

   my $ins_ver;
   my($version,$must) = @{$pkg{$pkg}};
   $version = sprintf("%.02f",$version);

   $ins_ver = defined ${$pkg . "::VERSION"}
                ? sprintf("%.02f",${$pkg . "::VERSION"})
                : undef;

   printf " %s %s, ",$pkg, (defined $ins_ver ? "Found v" . $ins_ver
                                             : "NOT FOUND");

   $ins_ver = "0.00" unless(defined $ins_ver);

   if($ins_ver < $version)
    {
     $abort += $must;
     printf "%s v%s\n", $must ? "REQUIRE " : "Recommend ", $version;
    }
   else
    {
     print "OK\n";
    }
  }

 die "Abort\n" if $abort;

 print "Done.\n";
}

sub initialize {
 local($_);

 check_installation(%chk_install);

 my $manifest = maniread();

 my %pl_files = ();
 my @exe_files = ();

 foreach (keys %$manifest) {
  $pl_files{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
  push(@exe_files,$_) if(m#\bbin/# && !m#demo#);
 }

 %hash = (
	VERSION   => $VERSION,
	NAME      => $NAME,
	DISTNAME  => $DISTNAME,
	SKIP      => [qw(static dynamic)],
	PL_FILES  => \%pl_files,
	EXE_FILES => \@exe_files,
	dist      => {COMPRESS     => 'gzip -9f',
		      SUFFIX       => 'gz',
		      DIST_DEFAULT => 'all tardist',
		      CI           => 'ci -l'
		     },
	linkext   => {LINKTYPE => ''},
	clean     => {FILES => '*% *.html *.bak *.old lib/*% lib/*/*% $(EXE_FILES)'},
 );

 \%hash;
}

sub MY::test {
    q{
TEST_VERBOSE=0

test:
	$(FULLPERL) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -e 'use Test::Harness qw(&runtests $$verbose); $$verbose=$(TEST_VERBOSE); runtests @ARGV;' t/*.t

};
}

sub MY::libscan {
    return '' if m:/(RCS|CVS)/:;
    return '' if m/[~%]$/;
    return '' if m/\.(orig|rej)$/;
    $_;
}

# -- Make the Makefile

die "You require MakeMaker v4.17 or later to install this package\n"
   unless($ExtUtils::MakeMaker::Version >= 4.17);

WriteMakefile(CONFIGURE => \&initialize);

