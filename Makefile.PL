# This -*- perl -*- script makes the Makefile
# $Id$

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

sub check_installation {
 my $must = shift;
 my %pkg = @_;
 my $pkg;
 foreach $pkg (keys %pkg) {
  eval "require $pkg;";

  my $rec_ver = sprintf("%.02f",$pkg{$pkg});

  if(!defined ${$pkg . "::VERSION"}) {
   if($must) {
    die "
*** You require $pkg version $rec_ver or later before you can
    use this installation

";
   }
   else {
    warn "
*** I recommend $pkg version $rec_ver or later, which is missing from your
    installation

";
   }
  }
  elsif(${$pkg . "::VERSION"} < $pkg{$pkg}) {
   my $ins_ver = sprintf("%.02f",${$pkg . "::VERSION"});

   if($must) {
    die "
*** You require $pkg version $rec_ver or later before you can
    use this installation, your installation contains version $ins_ver

";
   }
   else {
    warn "
*** I recommend $pkg version $rec_ver or later, your installation
    contains $pkg version $ins_ver

";
   }
  }
 }
}

sub initialize {
 local($_);

 check_installation(0,
                    Net::SMTP    => 1.03
                   );

 my $manifest = maniread();

 $Version = "0.00";

 eval { require "./History" };

 my %pl_files = ();
 my @exe_files = ();

 foreach (keys %$manifest) {
  $pl_files{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
  push(@exe_files,$_) if(m#\bbin/# && !m#demo#);
 }

 %hash = (
	VERSION   => $Version,
	NAME      => 'Mail',
	DISTNAME  => 'MailTools', 
	SKIP      => [qw(static dynamic)],
	PL_FILES  => \%pl_files,
	EXE_FILES => \@exe_files,

	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
		      DIST_DEFAULT => 'all tardist'
		     },

	'linkext' => {LINKTYPE => '' },
	'clean'   => {FILES => '*% *.html *.bak *.old lib/*% lib/*/*% $(EXE_FILES)'},
 );

 \%hash;
}


if ($ExtUtils::MakeMaker::Version < 4.17) {
    initialize();
} else {
    $hash{CONFIGURE} = \&initialize;
}

WriteMakefile(%hash);

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

