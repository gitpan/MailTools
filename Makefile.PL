# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.5 1996/08/13 09:28:13 gbarr Exp $

#--- Configuration section ---

%install_pgm = ();

#--- End User Configuration - You should not have to change anything below this line

require 5.001;

$VERSION = "1.06";
$NAME     = 'Mail';
$DISTNAME = 'MailTools';
$RELTYPE  = "";

$lib_only    = 0;

#--- End Configuration

use FileHandle;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

#--- MY package

sub MY::libscan
{
 my($self,$path) = @_;

 return '' 
	if($path =~ m:/(RCS|CVS|SCCS)/: ||
	   $path =~ m:[~%]$: ||
	   $path =~ m:\.(orig|rej)$:
	  );
 
 $path;
}

#--- End MY package

sub doIt
{
 my $manifest = maniread();
 
 my %PL_FILES = ();
 my %EXE_FILES = ();
 my %macro = ();

 #--- Install what ?
 
 foreach (keys %$manifest) {
  $PL_FILES{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
 
  if(m#\bbin/# && !m#demo#) {
   my $f = $_;
 
   $f =~ s#\.PL$##;
 
   if(defined $install_pgm{$f} && $install_pgm{$f}) {
    $EXE_FILES{$f} = 1 if(-x $f || -f "$f.PL");
   }
  }
 }
 
 %EXE_FILES = () if($lib_only);
 
 #--- Dist. VERSION
 
 unless(defined $VERSION)
  {
   my($pm,$rcs);
   my $fh = new FileHandle;
  
   ($pm = $NAME . ".pm") =~ s,.*::,,;
   ($pm = $NAME . ".pm") =~ s,::,/,g unless(-f $pm);
   $pm = "lib/" . $pm unless(-f $pm);
  
   if($fh->open($pm))
    {
     while (<$fh>)
      {
       chomp;
       next unless /\$([\w:]*\bVERSION)\b.*=/;
       my $module_version_variable = $1;
       my($eval) = "$_;";
       eval $eval;
       die "Could not eval '$eval': $@" if $@;
       $VERSION = $ {$module_version_variable};
       last;
      }
     close $fh;
    }
  
   ($rcs = $pm) =~ s:([^/]+\.pm):RCS/$1,v:;
  
   # update VERSION when checked in
   $macro{CONFIGDEP} = $rcs
     if(-f $rcs);
  }
 
 $VERSION .= $RELTYPE
 	if(defined $RELTYPE);
 
 #--- Write the Makefile
 
 %hash = (
	VERSION   => $VERSION,
	NAME      => $NAME,
	PL_FILES  => \%PL_FILES,
	EXE_FILES => [ keys %EXE_FILES ],
 
	'linkext' => {LINKTYPE => '' },
	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
		      POSTOP   => 'mv $(DISTNAME)-$(VERSION).tar.gz ../',
		      DIST_DEFAULT => 'all tardist',
		      CI => 'ci -l'
		     },
 
	'clean'   => {FILES => join(" ", qw(*% *.html *.bak *.old lib/*% lib/*/*%),values %PL_FILES)},
 );
 
 $hash{macro} = \%macro
 	if(%macro);
 
 $hash{DISTNAME} = $DISTNAME
 	if(defined $DISTNAME);
 
 WriteMakefile( %hash ) ;
 
}

#--- Installation check

sub chk_version
{
 my($pkg,$wanted,$msg) = @_;

 $| = 1;
 print "Checking for $pkg...";

 eval "require $pkg";

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
	. "Look on CPAN for CPAN/modules/by-author/id/GBARR/Net-FTP-x.x.tar.gz\n\n";

chk_version(Net::Domain => 1.05) or
    warn  "\n"
	. "It is reccomended that you have Net::Domain version 1.05 or later\n"
	. "Look on CPAN for CPAN/modules/by-author/id/GBARR/Net-Domain-x.x.tar.gz\n\n";

#--- Write the Makefile

doIt();
