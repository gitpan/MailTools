# Mail::Header.pm
#
# Copyright (c) 1995 Graham Barr <Graham.Barr@tiuk.ti.com>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#
# The internals of this package are implemented in terms of a list of lines
# and a hash indexed by the tags. The hash contains a list of references to
# the actual SV's in the list. We therefore do our upmost to preserve this.
# anyone who delves into these structures deserve all they get.
#

package Mail::Header;

=head1 NAME

Mail::Header - manipulate mail RFC822 compliant headers

=head1 SYNOPSIS

    use Mail::Header;
    
    $head = new Mail::Header;
    $head = new Mail::Header \*STDIN;
    $head = new Mail::Header [<>], Modify => 0;

=head1 DESCRIPTION

This package provides a class object which can be used for reading, creating,
manipulating and writing RFC822 compliant headers.

=head1 CONSTRUCTOR

=over 4

=item new ( [ ARG ], [ OPTIONS ] )

C<ARG> may be either a file descriptor (reference to a GLOB)
or a reference to an array. If given the new object will be
initialized with headers either from the array of read from 
the file descriptor.

C<OPTIONS> is a list of options given in the form of key-value
pairs, just like a hash table. Valid options are

=over 8

=item B<Reformat>

If this value is I<true> then the headers will be re-formatted,
otherwise the format of the header lines will remain unchanged.

=item B<MailFrom>

This option specifies what to do when a header in the form `From '
is encountered. Valid values are C<IGNORE> - ignore and discard the header,
C<ERROR> - invoke an error (call die), C<COERCE> - rename them as Mail-From
and C<KEEP> - keep them.

=item B<FoldLength>

The default length of line to be used when folding header lines

=back

=back

=head1 METHODS

=over 4

=item modify ( [ VALUE ] )

=item mail_from ( OPTION )

=item fold ( [ LENGTH ] )

=item extract ( ARRAY_REF )

=item read ( FD )

=item empty ()

=item header ( [ ARRAY_REF ] )

=item add ( TAG, LINE [, INDEX ] )

=item replace ( TAG, LINE [, INDEX ] )

=item combine ( TAG [, WITH ] )

=item get ( TAG [, INDEX ] )

=item exists ( TAG )

=item delete ( TAG [, INDEX ] )

=item print ( [ FD ] )

=item fold_length ( [ LENGTH ] )

=item tags ()

=item dup ()

=item cleanup ()

=back

=head1 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head1 COPYRIGHT

Copyright (c) 1996 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=head1 REVISION

$Revision: 1.1 $
$Date: 1996/08/13 09:26:15 $

The VERSION is derived from the revision turning each number after the
first dot into a 2 digit number so

	Revision 1.8   => VERSION 1.08
	Revision 1.2.3 => VERSION 1.0203

=cut

require 5.002;

use Carp;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my $MAIL_FROM = 'KEEP';
my %HDR_LENGTHS = ();

#
# Pattern to match a RFC822 Field name ( Extract from RFC #822)
#
#     field       =  field-name ":" [ field-body ] CRLF
#
#     field-name  =  1*<any CHAR, excluding CTLs, SPACE, and ":">
#
#     CHAR        =  <any ASCII character>        ; (  0-177,  0.-127.)
#     CTL         =  <any ASCII control           ; (  0- 37,  0.- 31.)
#
# I have included the trailing ':' in the field-name
#
$FIELD_NAME = '[^\x00-\x1f\x80-\xff :]+:';

##
## Private functions
##

sub _error { warn @_; return (wantarray ? () : undef) }

# tidy up internal hash table and list

sub _tidy_header
{
 my $me = shift;
 my($ref,$key);
 my $i;
 my $d = 0;

 for($i = 0 ; $i < scalar(@{$me->{'mail_hdr_list'}}) ; $i++)
  {
   unless(defined $me->{'mail_hdr_list'}[$i])
    {
     splice(@{$me->{'mail_hdr_list'}},$i,1);
     $d++;
     $i--;
    }
  }

 if($d)
  {
   while(($key,$ref) = each %{$me->{'mail_hdr_hash'}} )
    {
     local $_;

     @$ref = grep { ref($_) && defined $$_ } @$ref;
     delete $me->{'mail_hdr_hash'}{$key}
	unless @$ref;
    }
  }
}

# fold the line to the given length

sub _fold_line
{
 my($ln,$maxlen) = @_;

 $maxlen = 20
    if($maxlen < 20);

 my $max = int($maxlen - 5);         # 4 for leading spcs + 1 for [\,\;]
 my $min = int($maxlen * 4 / 5) - 4;
 my $ml = $maxlen;

 $_[0] =~ s/\s*[\r\n]+\s*/ /og; # Compress any white space around a newline
 $_[0] =~ s/\s*\Z/\n/so;        # End line with a EOLN

 if(length($_[0]) > $ml)
  {
   #Split the line up
   # first bias towards splitting at a , or a ; >4/5 along the line
   # next split a whitespace
   # else we are looking at a single word and probably don't want to split

   $_[0] =~ s/\s*(.{$min,$max}?[\,\;]|.{1,$max}[\s\n]|\S+[\s\n])/\n    $1/g;
   $_[0] =~ s/(\A\s+|[\t ]+\Z)//sog;
  }

 $_[0] =~ s/\A(\S+\s)[\s\n]*/$1/so; 
}

# attempt to change the case of a tag to that required by RFC822. That
# being all characters are lowercase except the first of each word. Also
# if the word is an `acronym' then all characters are uppercase. We decide
# a word is an acronym if it does not contain a vowel.

sub _tag_case
{
 my $tag = shift;

 $tag =~ s/:\Z//o;

 # Change the case of the tag
 # eq Message-Id
 $tag =~ s/\b([a-z]+)/\L\u$1/gio;
 $tag =~ s/\b([b-df-hj-np-tv-z]+)\b/\U$1/gio;

 $tag;
}

# format a complete line
#  ensure line starts with the given tag
#  ensure tag is correct case
#  change the 'From ' tag as required
#  fold the line

sub _fmt_line
{
 my $me = shift;
 my $tag = shift;
 my $line = shift;
 my $modify = shift || $me->{'mail_hdr_modify'};
 my $ctag = undef;

 ($tag) = $line =~ /\A($FIELD_NAME|From )/oi
    unless(defined $tag);

 if($tag =~ /\AFrom /io && $me->{'mail_hdr_mail_from'} ne 'KEEP')
  {
   if ($me->{'mail_hdr_mail_from'} eq 'COERCE')
    {
     $line =~ s/^From /Mail-From: /o;
     $tag = "Mail-From:";
    }
   elsif ($me->{'mail_hdr_mail_from'} eq 'IGNORE')
    {
     return ();
    }
   elsif ($me->{'mail_hdr_mail_from'} eq 'ERROR')
    {
     return _error "unadorned 'From ' ignored: <$line>"
    }
  }

 if(defined $tag)
  {
   $tag = _tag_case($ctag = $tag);

   $ctag = $tag
   	if($modify);

   $ctag =~ s/([^ :])\Z/$1:/o;
  }

 croak( "Bad RFC822 field name '$tag'\n")
   unless(defined $ctag && $ctag =~ /\A($FIELD_NAME|From )/oi);

 # Ensure the line starts with tag
 $line =~ s/\A($ctag)?\s*/$ctag /i
    if $modify || $line !~ /\A$ctag/i ;

 my $maxlen = $me->{'mail_hdr_lengths'}{$tag}
		|| $HDR_LENGTHS{$tag}
		|| $me->fold_length;

 _fold_line($line,$maxlen)
    if $modify && defined $maxlen;

 $line =~ s/\n*\Z/\n/so;

 ($tag, $line);
}

sub _insert
{
 my($me,$tag,$line,$where) = @_;

 if($where < 0)
  {
   $where = scalar(@{$me->{'mail_hdr_list'}}) + $where + 1;

   $where = 0
	if($where < 0);
  }
 elsif($where >= scalar(@{$me->{'mail_hdr_list'}}))
  {
   $where = scalar(@{$me->{'mail_hdr_list'}});
  }

 my $atend = $where == scalar(@{$me->{'mail_hdr_list'}});

 splice(@{$me->{'mail_hdr_list'}},$where,0,$line);

 $me->{'mail_hdr_hash'}{$tag} ||= [];
 my $ref = \${$me->{'mail_hdr_list'}}[$where];

 if(scalar($me->{'mail_hdr_hash'}{$tag}) && $where)
  {
   if($atend)
    {
     push(@{$me->{'mail_hdr_hash'}{$tag}}, $ref);
    }
   else
    {
     my($ln,$i,$ref);
     $i = 0;
     foreach $ln (@{$me->{'mail_hdr_list'}})
      {
       my $r = \$ln;
       last if($r == $ref);
       $i++ if($r == $me->{'mail_hdr_hash'}{$tag}[$i]);
      }
     splice(@{$me->{'mail_hdr_hash'}{$tag}},$i,0,$ref);
    }
  }
 else
  {
   unshift(@{$me->{'mail_hdr_hash'}{$tag}}, $ref);
  }
}

##
## Constructor
##

sub new
{
 my $self = shift;
 my $type = ref($self) || $self;
 my $arg = @_ % 2 ? shift : undef;
 my %arg = @_;

 my %hash = (
	mail_hdr_list     => [],
	mail_hdr_hash     => {},
	mail_hdr_modify   => delete $arg{Reformat} || 0,
	mail_hdr_foldlen  => 79,
	mail_hdr_lengths  => {}
	);

 my $me = bless \%hash, $type;

 $me->mail_from( uc($arg{'MailFrom'} || $MAIL_FROM) );

 $me->fold_length($arg{FoldLength})
    if exists $arg{FoldLength};

 if(ref $arg)
  {
   if(ref($arg) eq 'ARRAY')
    {
     $me->extract([ @{$arg} ]);
    }
   elsif(defined fileno($arg))
    {
     $me->read($arg);
    }
  }

 $me;
}

sub modify
{
 my $me = shift;
 my $old = $me->{'mail_hdr_modify'};

 $me->{'mail_hdr_modify'} = 0 + shift
	if @_;

 $old;
}

sub mail_from
{
 my $me = shift;
 my $choice = uc(shift);

 $choice =~ /^(IGNORE|ERROR|COERCE|KEEP)$/ 
	or die "bad Mail-From choice: '$choice'";

 if(ref($me))
  {
   $me->{'mail_hdr_mail_from'} = $choice;
  }
 else
  {
   $MAIL_FROM = $choice;
  }

 $me;
}

sub fold
{
 my $me = shift;
 my $maxlen = shift;
 my($tag,$list,$ln);

 while(($tag,$list) = each %{$me->{'mail_hdr_hash'}})
  {
   my $len = $maxlen
		|| $me->{'mail_hdr_lengths'}{$tag}
		|| $HDR_LENGTHS{$tag}
		|| $me->fold_length;

   foreach $ln (@$list)
    {
     _fold_line($ln,$len)
        if defined $ln;
    }
  }

 $me;
}

sub unfold
{
 my $me = shift;
 my($tag,$list,$ln);

 if(@_)
  {
   $tag = _tag_case(shift);
   return $me unless exists $me->{'mail_hdr_hash'}{$tag};
   $list = $me->{'mail_hdr_hash'}{$tag};
   foreach $ln (@$list)
    {
     $ln =~ s/\r?\n\s+/ /sog
	if defined $ln;
    }
  }
 else
  {
   while(($tag,$list) = each %{$me->{'mail_hdr_hash'}})
    {
     foreach $ln (@$list)
      {
       $ln =~ s/\r?\n\s+/ /sog
	    if defined $ln;
      }
    }
  }
 $me;
}

sub extract
{
 my $me = shift;
 my $arr = shift;
 my $line;

 $me->empty;

 while(scalar(@{$arr}) && $arr->[0] =~ /\A($FIELD_NAME|From )/o)
  {
   my $tag = $1;

   $line = shift @{$arr};
   $line .= shift @{$arr}
       while(scalar(@{$arr}) && $arr->[0] =~ /\A[ \t]+\S/o);

   ($tag,$line) = _fmt_line($me,$tag,$line);

   _insert($me,$tag,$line,-1)
      if defined $line;
  }

 shift @{$arr}
  if(scalar(@{$arr}) && $arr->[0] =~ /\A\s*\Z/o);

 $me;
}

sub read
{
 my $me = shift;
 my $fd = shift;

 $me->empty;

 my $line = undef;
 my $ln = "";
 my $tag = undef;

 while(1)
  {
   $ln = <$fd>;

   if(defined $ln && defined $line && $ln =~ /\A[ \t]+\S/o)
    {
     $line .= $ln;
     next;
    }

   if(defined $line)
    {
     ($tag,$line) = _fmt_line($me,$tag,$line);
      _insert($me,$tag,$line,-1)
	if defined $line;
    }

   last
     unless(defined $ln && $ln =~ /\A($FIELD_NAME|From )/o);

   $tag  = $1;
   $line = $ln;
  }

 $me;
}

sub empty
{
 my $me = shift;

 $me->{'mail_hdr_list'} = [];
 $me->{'mail_hdr_hash'} = {};

 $me;
}

sub header
{
 my $me = shift;

 $me->extract(@_)
	if(@_);

 $me->fold
    if $me->{'mail_hdr_modify'};

 # Must protect ourself against corruption as the hash contains refs to the
 # SV's in the list, if the user modifies this list we are really screwed :-

 [ @{$me->{'mail_hdr_list'}} ];
}

sub add
{
 my $me = shift;
 my($tag,$text,$where) = @_;

 ($tag,$line) = _fmt_line($me,$tag,$text);

 # Must have a tag and text to add
 return undef
	unless(defined $tag && defined $line);

 $where = -1
	unless defined $where;

 _insert($me,$tag,$line,$where);

 return substr($line, length($tag) + 2);
}

sub replace
{
 my $me = shift;
 my $idx = 0;
 my($tag,$line);

 $idx = pop @_
    if(@_ % 2);

TAG:
 while(@_)
  {
   ($tag,$line) = _fmt_line($me,splice(@_,0,2));

   return undef
        unless(defined $tag && defined $line);

   if(exists $me->{'mail_hdr_hash'}{$tag} &&
      defined $me->{'mail_hdr_hash'}{$tag}[$idx])
    {
     ${$me->{'mail_hdr_hash'}{$tag}[$idx]} = $line;
    }
   else
    {
     _insert($me,$tag,$line,-1);
    }
  }

 return substr($line, length($tag) + 2);
}

sub combine
{
 my $me  = shift;
 my $tag = _tag_case(shift);
 my $with = shift || ' ';
 my $line;

 return _error "unadorned 'From ' ignored: <$line>"
	if($tag =~ /^From /io && $me->{'mail_hdr_mail_from'} ne 'KEEP');

 return undef
    unless exists $me->{'mail_hdr_hash'}{$tag};

 if(scalar(@{$me->{'mail_hdr_hash'}{$tag}}) > 1)
  {
   my @lines = $me->get($tag);

   chomp(@lines);

   map { $$_ = undef } @{$me->{'mail_hdr_hash'}{$tag}};

   ${$me->{'mail_hdr_hash'}{$tag}[0]} = 
        (_fmt_line($me,$tag, join($with,@lines),1))[1];

   _tidy_header($me);
  }

 return substr($line, length($tag) + 2);
}

sub get
{
 my $me = shift;
 my $tag = _tag_case(shift);
 my $idx = shift;

 return wantarray ? () : undef
    unless exists $me->{'mail_hdr_hash'}{$tag};

 my $l = length($tag) + 2;

 $idx = 0
    unless defined $idx || wantarray;

 if(defined $idx)
  {
   return defined $me->{'mail_hdr_hash'}{$tag}[$idx]
        ? substr(${$me->{'mail_hdr_hash'}{$tag}[$idx]}, $l)
        : undef;
  }

 return  map { substr($$_,$l) } @{$me->{'mail_hdr_hash'}{$tag}};
}

sub exists
{
 my $me = shift;
 my $tag = _tag_case(shift);

 exists $me->{'mail_hdr_hash'}{$tag}
	? scalar(@{$me->{'mail_hdr_hash'}{$tag}})
	: 0;
}

sub delete
{
 my $me  = shift;
 my $tag = _tag_case(shift);
 my $idx = shift;
 my @val = ();

 if(defined $me->{'mail_hdr_hash'}{$tag})
  {
   my $l = length($tag) + 2;
   if(defined $idx)
    {
     if(defined $me->{'mail_hdr_hash'}{$tag}[$idx])
      {
       push(@val, substr(${$me->{'mail_hdr_hash'}{$tag}[$idx]},$l));
       undef ${$me->{'mail_hdr_hash'}{$tag}[$idx]};
      }
    }
   else
    {
     local $_;
     @val = map {
                 my $x = substr($$_,$l);
                 undef $$_;
                 $x
                } @{$me->{'mail_hdr_hash'}{$tag}};
    }

   _tidy_header($me);
  }

 return @val;
}

sub print
{
 my $me = shift;
 my $fd = shift || \*STDOUT;
 my $ln;

 foreach $ln (@{$me->{'mail_hdr_list'}})
  {
   next
    unless defined $ln;
   print $fd $ln or
    return 0;
  }

 1;
}

sub fold_length
{
 my $me  = shift;
 my $old;

 if(@_ == 2)
  {
   my($tag,$len) = @_;

   my $hash = ref($me) ? $me->{'mail_hdr_lengths'} : \%HDR_LENGTHS;

   $tag = _tag_case($tag);

   $old = $hash->{$tag} || undef;
   $hash->{$tag} = $len > 20 ? $len : 20;
  }
 else
  {
   my $len = shift;

   $old = $me->{'mail_hdr_foldlen'};

   if(defined $len)
    {
     $me->{'mail_hdr_foldlen'} = $len > 20 ? $len : 20;
     $me->fold;
    }
  }

 $old;
}

sub tags
{
 my $me = shift;

 keys %{$me->{'mail_hdr_hash'}};
}

sub dup
{
 my $me = shift;
 my $type = ref($me) || croak "Cannot dup without an object";
 my $dup = new $type;

 %$dup = %$me;
 $dup->empty;

 $dup->{'mail_hdr_list'} = [ @{$me->{'mail_hdr_list'}} ];

 my $ln;
 foreach $ln ( @{$dup->{'mail_hdr_list'}} )
  {
   my $tag = _tag_case(($ln =~ /\A($FIELD_NAME|From )/oi)[0]);

   $dup->{'mail_hdr_hash'}{$tag} ||= [];
   push(@{$dup->{'mail_hdr_hash'}{$tag}}, \$ln);
  }

 $dup;
}

sub cleanup
{
 my $me = shift;
 my $d = 0;
 my $arr;

 foreach $arr (values %{$me->{'mail_hdr_hash'}})
  {
   my $ref;
   foreach $ref (@$arr)
    {
     unless($$ref =~ /\A($FIELD_NAME|From )\s*\S/soi)
      {
       $$ref = undef;
       $d++;
      }
    }
  }

 _tidy_header($me)
	if $d;

 $me;  
}

1; # keep require happy


