# Mail::Address.pm
#
# Copyright (c) 1995-7 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mail::Address;
use strict;

=head1 NAME

Mail::Address - Parse mail addresses

=head1 SYNOPSIS

    use Mail::Address;
    
    my @addrs = Mail::Address->parse($line);
    
    foreach $addr (@addrs) {
	print $addr->format,"\n";
    }

=head1 DESCRIPTION

C<Mail::Address> extracts and manipulates RFC822 compilant email
addresses. As well as being able to create C<Mail::Address> objects
in the normal manner, C<Mail::Address> can extract addresses from
the To and Cc lines found in an email message.

=head1 CONSTRUCTORS

=over 4

=item new( PHRASE,  ADDRESS, [ COMMENT ])

 Mail::Address->new("Perl5 Porters", "perl5-porters@africa.nicoh.com");

Create a new C<Mail::Address> object which represents an address with the
elements given. In a message these 3 elements would be seen like:

 PHRASE <ADDRESS> (COMMENT)
 ADDRESS (COMMENT)

=item parse( LINE )

 Mail::Address->parse($line);

Parse the given line a return a list of extracted C<Mail::Address> objects.
The line would normally be one taken from a To,Cc or Bcc line in a message

=back

=head1 METHODS

=over 4

=item phrase ()

Return the phrase part of the object.

=item address ()

Return the address part of the object.

=item comment ()

Return teh comment part of the object

=item format ()

Return a string representing the address in a suitable form to be placed
on a To,Cc or Bcc line of a message

=item name ()

Using the information contained within the object attempt to identify what
the person or groups name is

=item host ()

Return the address excluding the user id and '@'

=item user ()

Return the address excluding the '@' and the mail domain

=item path ()

Unimplemented yet but should return the UUCP path for the message

=item canon ()

Unimplemented yet but should return the UUCP canon for the message

=back

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 COPYRIGHT

Copyright (c) 1995-7 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut

use Carp;
use vars qw($VERSION);

$VERSION = do { my @r=(q$Revision: 1.12 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};
sub Version { $VERSION }

#
# given a comment, attempt to extract a person's name
#

sub _extract_name
{
 local $_ = shift || '';
 s/\A\(|\)\Z//go;	# (...)

 s/\(.*\)//go;		# remove inbeded comments

 s/(([a-z]+|[a-z]\-[a-z])+)\s*,?\s*(([a-z]\s*\.\s*)+)(\[^\sa-z]|\Z)/$3 $1/io;	# change Barr, G. M. => G. M. Barr
 s/\A[^a-z]*(([a-z \-\.]|[a-z]\-[a-z])+).*/$1/igo;			# remove leading/trailing punctuation

 s/[\.\s]+/ /go;		# change . => ' ' and condense spaces

 return $_;
}

sub _tokenise {
 local($_) = join(',', @_);
 my(@words,$snippet,$field);
 
 s/\A\s+//;
 s/[\r\n]+/ /g;

 while ($_ ne '')
  {
   $field = '';
   if( /^\s*\(/ )    # (...)
    {
     my $depth = 0;

     while(s/^\s*(\(([^\(\)\\]|\\.)*)//)
      {
       $field .= $1;
       $depth++;
       while($depth && s/^(([^\(\)\\]|\\.)*\)\s*)//)
        {
         $depth--;
         $field .= $1;
        }
      }

     carp "Unmatched () '$field' '$_'"
        if $depth;

     $field =~ s/\s+\Z//;
     push(@words, $field);

     next;
    }

      s/^("([^"\\]|\\.)*")\s*//       # "..."
   || s/^(\[([^\]\\]|\\.)*\])\s*//    # [...]
   || s/^([^\s\Q()<>\@,;:\\".[]\E]+)\s*//
   || s/^([\Q()<>\@,;:\\".[]\E])\s*//
     and do { push(@words, $1); next; };

   croak "Unrecognised line: $_";
  }

 push(@words, ",");

 \@words;
}

sub _find_next {
 my $idx = shift;
 my $tokens = shift;
 my $len = shift;
 while($idx < $len) {
   my $c = $tokens->[$idx];
   return $c if($c eq "," || $c eq "<");
   $idx++;
 }
 return "";
}

sub _complete {
 my $pkg = shift;
 my $phrase = shift;
 my $address = shift;
 my $comment = shift;
 my $o = undef;

 if(@{$phrase} || @{$comment} || @{$address}) {
  $o = $pkg->new(join(" ",@{$phrase}), 
                 join("", @{$address}),
                 join(" ",@{$comment}));
  @{$phrase} = ();
  @{$address} = ();
  @{$comment} = ();
 }

 return $o;
}


sub new {
 my $pkg = shift;
 my $me = bless [@_], $pkg;
 return $me;
}


sub parse {
 my $pkg = shift;

 local $_;

 my @phrase  = ();
 my @comment = ();
 my @address = ();
 my @objs    = ();
 my $depth   = 0;
 my $idx = 0;
 my $tokens = _tokenise(@_);
 my $len = scalar(@{$tokens});
 my $next = _find_next($idx,$tokens,$len);

 for( ; $idx < $len ; $idx++) {
  $_ = $tokens->[$idx];

  if(substr($_,0,1) eq "(") {
   push(@comment,$_);
  }
  elsif($_ eq '<') {
   $depth++;
  }
  elsif($_ eq '>') {
   $depth-- if($depth);
   unless($depth) {
    my $o = _complete($pkg,\@phrase, \@address, \@comment);
    push(@objs, $o) if(defined $o);
    $depth = 0;
    $next = _find_next($idx,$tokens,$len);
   }
  }
  elsif($_ eq ',') {
   warn "Unmatched '<>'" if($depth);
   my $o = _complete($pkg,\@phrase, \@address, \@comment);
   push(@objs, $o) if(defined $o);
   $depth = 0;
   $next = _find_next($idx+1,$tokens,$len);
  }
  elsif($depth) {
   push(@address,$_);
  }
  elsif($next eq "<") {
   push(@phrase,$_);
  }
  elsif($_ =~ /\A[\Q.\@:;\E]\Z/ || !scalar(@address) || $address[$#address] =~ /\A[\Q.\@:;\E]\Z/) {
   push(@address,$_);
  }
  else {
   warn "Unmatched '<>'" if($depth);
   my $o = _complete($pkg,\@phrase, \@address, \@comment);
   push(@objs, $o) if(defined $o);
   $depth = 0;
   push(@address,$_);
  }
 }
 @objs;
}

sub set_or_get {
 my $me = shift;
 my $i = shift;
 my $val = $me->[$i];

 $me->[$i] = shift if(@_);

 $val;
}


sub phrase  { set_or_get(shift,0,@_) }
sub address { set_or_get(shift,1,@_) }
sub comment { set_or_get(shift,2,@_) }


sub format {
 my @fmts = ();
 my $me;

 foreach $me (@_) {
   my($phrase,$addr,$comment) = @{$me};
   my @tmp = ();

   if(defined $phrase && length($phrase)) {
    push(@tmp, $phrase);
    push(@tmp, "<" . $addr . ">") if(defined $addr && length($addr));
   }
   else {
    push(@tmp, $addr) if(defined $addr && length($addr));
   }
   push(@tmp, $comment) if(defined $comment && length($comment));
   push(@fmts, join(" ", @tmp)) if(scalar(@tmp));
 }

 return join(", ", @fmts);
}


sub name {
 my $me = shift;
 my $phrase = $me->phrase;
 my $addr = $me->address;

 $phrase = $me->comment unless(defined($phrase) && length($phrase));

 my $name = _extract_name($phrase);
 
 if($name eq '' && $addr =~ /([^\%\.\@\_]+([\.\_][^\%\.\@\_]+)+)[\@\%]/o)	# first.last@domain address
  {
   ($name = $1) =~ s/[\.\_]+/ /go;
   $name = _extract_name($name);
  }
 
 if($name eq '' && $addr =~ m#/g=#oi)	# X400 style address
  {
   my ($f) = $addr =~ m#g=([^/]*)#oi;
   my ($l) = $addr =~ m#s=([^/]*)#io;
 
   $name = _extract_name($f . " " . $l);
  }

 #
 # Set the case of the name to first char upper rest lower
 #

 $name =~ s/\b([a-z]+)/\L\u$1/igo; 	    # Upcase first letter on name
 $name =~ s/\bMc([a-z])/Mc\u$1/igo;	    # Scottish names such as 'McLeod'
 $name =~ s/\b(x*(ix)?v*(iv)?i*)\b/\U$1/igo; # Roman numerals
					    #   eg 'Level III Support'

 # Roman numerals upto M (I think ?)
 # m*([cxi]m)?d*([cxi]d)?c*([xi]c)?l*([xi]l)?x*(ix)?v*(iv)?i*
 $name =~ s/(\A\s+|\s+\Z)//go;
 return length($name) ? $name : undef;
}


sub host {
 my $me = shift;
 my $addr = $me->address;
 my $i = rindex($addr,'@');

 my $host = ($i >= 0) ? substr($addr,$i+1) : undef;

 return $host;
}


sub user {
 my $me = shift;
 my $addr = $me->address;
 my $i = index($addr,'@');

 my $user = ($i >= 0) ? substr($addr,0,$i) : $addr;

 return $user;
}


sub path {
 return ();
}


sub canon {
 my $me = shift;
 return ($me->host, $me->user, $me->path);
}

1;


