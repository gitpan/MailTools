#

package Mail::Alias;

use Carp;

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

sub new {
 my $pkg = shift;

 my $me = bless {}, $pkg;

 $me->read(@_) if(@_);

 $me;
}

sub format {
 my $me = shift;
 my $fmt = shift;
 my $pkg = "Mail::Alias::" . $fmt;

 croak "Unknown format '$fmt'"
  unless defined @{$pkg . "::ISA"};

 bless $me, $pkg;
}

sub exists {
 my $me = shift;
 my $alias = shift;

 return defined $me->{$alias};
}

sub expand {
 my $me = shift;
 my @result = ();
 my %done = ();
 my $alias;
 my @todo = @_;

 while($alias = shift(@todo)) {
  next if(defined $done{$alias});
  $done{$alias} = 1;
  if(defined $me->{$alias}) {
   push(@todo,@{$me->{$alias}});
  }
  else {
   push(@result,$alias);
  }
 }
 wantarray ? @result : \@result;
}

package Mail::Alias::Ucbmail;

@ISA = qw(Mail::Alias::Binmail);

package Mail::Alias::Binmail;

use Carp;
use Mail::Address;

@ISA = qw(Mail::Alias);

sub read {
 my $me = shift;
 my $file = shift;

 open(ALIAS,$file) || croak "Cannot open $file: $!\n";

 while(<ALIAS>) {
  next unless(/^\s*(alias|group)\s+(\S+)\s+(.*)/);
  my($group,$who) = ($2,$3);

  $who =~ s/(\A[\s,]+|[\s,]+\Z)//g;

  my @resp = ();

  while(length($who)) {
#   $who =~ s/\A([^\"]\S*|\"[^\"]*\")\s*//;
#   my $ln = $1;
#   $ln =~ s/\A\s*\"|\"\s*\Z//g;     
 $who =~ s/\A\s*(\"?)([^\"]*)\1\s*//;
   push(@resp,$2);
#   push(@resp,$ln);
  }
  $me->{$group} = [ @resp ];
 }
 close(ALIAS);
}

sub write {
 my $me = shift;
 my $file = shift;
 my $alias;
 my $fd;

 if(ref($file)) {
  $fd = $file;
 }
 else {
  open(ALIAS,$file) || croak "Cannot open $file: $!\n";
  $fd = \*ALIAS;
 }

 foreach $alias (sort keys %$me) {
  my @a = @{$me->{$alias}};
  map { $_ = '"' . $_ . '"' if /\s/ } @a;
  print $fd "alias $alias ",join(" ",@a),"\n";
 }

 close(ALIAS) if($fd == \*ALIAS);
}

package Mail::Alias::Sendmail;

use Carp;
use Mail::Address;

@ISA = qw(Mail::Alias);

sub write {
 my $me = shift;
 my $file = shift;
 my $alias;
 my $fd;

 if(ref($file)) {
  $fd = $file;
 }
 else {
  open(ALIAS,$file) || croak "Cannot open $file: $!\n";
  $fd = \*ALIAS;
 }

 foreach $alias (sort keys %$me) {
  my $ln = $alias . ": " . join(", ",@{$me->{$alias}});
  $ln =~ s/(.{55,78},)/$1\n\t/g;
  print $fd $ln,"\n";
 }

 close(ALIAS) if($fd == \*ALIAS);
}

sub _include_file {
 my $file = shift;
 local *INC;
 my @ln;
 local $_;
 open(INC,$file) or carp "Cannot open file '$file'" and return "";
 @ln = grep(/^[^#]/,<INC>);
 close(INC);
 chomp(@ln);
 join(",",@ln);
}

sub read {
 my $me = shift;
 my $file = shift;

 open(ALIAS,$file) || croak "Cannot open $file: $!\n";

 my $group = undef;
 my $line = undef;

 while(<ALIAS>) {
  chomp;
  if(defined $line && /^\s/) {
   $line .= $_;
  }
  else {
   if(defined $line) {
    if($line =~ s/^([^:]+)://) {
     my @resp;
     $group = $1;
     $group =~ s/(\A\s+|\s+\Z)//g;
     $line =~ s/\"?:include:(\S+)\"?/_include_file($1)/eg;
     $line =~ s/(\A[\s,]+|[\s,]+\Z)//g;

     while(length($line)) {
      $line =~ s/\A([^\"][^ \t,]+|\"[^\"]+\")(\s*,\s*)*//;
      push(@resp,$1);
     }

     $me->{$group} = \@resp;
    }
    undef $line;
   }
   next if (/^#/ || /^\s*$/);
   $line = $_;
  }
 }
 close(ALIAS);
}

1;

