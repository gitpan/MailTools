# Mail::Internet.pm
#
# Copyright (c) 1995 Graham Barr <Graham.Barr@tiuk.ti.com>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mail::Internet;

$VERSION = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

=head1 SYNOPSIS

use Mail::Internet;

=head1 DESCRIPTION

This package provides a class object which can be used for reading, creating,
manipulating and writing a message with RFC822 compliant headers.

=cut

require 5.000;
use Carp;
use AutoLoader;
@ISA = qw(AutoLoader);
#
# Pattern to match a RFC822 Feild name ( Extract from RFC #822)
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

sub tidy_headers
{
 local $_;

 my $me = shift;

 # Remove any entries without tags & text
 @{$me->{Hdrs}} = grep(defined $_, @{$me->{Hdrs}});
}

sub tag_case
{
 my $tag = shift;
 my $line = shift;

 if(defined $line)
  {
   ($tag) = $line =~ /\A($FIELD_NAME|From )/i unless(defined $tag);

   # Remove any line continuations and surrounding white-space
   $line =~ s/\s*[\r\n]+\s*/ /g;
   $line =~ s/\A\s+//;
  }

 if(defined $tag)
  {
   # Ensure tag ends with a ':'
   $tag .= ":" unless $tag =~ /(\AFrom |:)\Z/;

   # Change the case of the tag
   # eq Message-Id
   $tag =~ s/\b([a-z]+)/\L\u$1/gi;

   # Ensure the line starts with tag
   $line =~ s/\A(\Q$tag\E)?\s*/$tag /i if(defined $line);
  }

 croak( "Bad RFC822 field name '$tag'\n")
   unless(defined $tag && $tag =~ /\A($FIELD_NAME|From )/i);

 # Return either just the tag or both
 return wantarray ? ($tag, $line) : $tag;
}

sub fold
{
 local $_;

 my $me = shift;
 my $maxlen = $me->fold_length;

 $maxlen = 20 if($maxlen < 20);

 my $max = int($maxlen - 5);         # 4 for leading spcs + 1 for [\,\;]
 my $min = int($maxlen * 4 / 5) - 4;

 foreach (scalar(@_) ? @_ : @{$me->{Hdrs}})
  {
   s/\s*[\r\n]+\s*/ /g; # Compress any white space around a newline
   s/\s*\Z/\n/;         # End line with a EOLN

   next if(length($_) <= $maxlen) ; # quick exit

   #
   #Split the line up
   # first bias towards splitting at a , or a ; >4/5 along the line
   # next split a whitespace
   # else we are looking at a single word and probably don't want to split
   #
  
   s/\s*(.{$min,$max}?[\,\;]|.{1,$max}[\s\n]|\S+[\s\n])/\n    $1/g;
   $_ = substr($_,5);
  }

 return scalar(@_) ? $_[0] : $me->{Hdrs};
}

##
## Constructor
##

=head2 CONSTRUCTOR

=over 2

=item new

The new constructor accepts either an array or a reference to an array. It
returns a blessed reference.

 Mail::Internet->new( <> );       # Read message from STDIN
 Mail::Internet->new( $arr_ref ); # Read message from @{$arr_ref}

=cut

sub new
{
 my $pkg = shift;

 local $[ = 0;

 my $me   = bless {}, $pkg;
 my $arr  = [];
 my ($line,$buffer);
 my $fd = undef;

 $me->{FoldLen} = 79; # Default fold length
 $me->{Body} = [];
 $me->{Hdrs} = [];

 @{$arr} = @_ if(scalar(@_) > 1);

 if(scalar(@_) == 1) {
  if(ref($_[0]) eq 'ARRAY') {
   @{$arr} = @{$_[0]};
  }
  elsif(fileno($fd = $_[0])) {
   undef $arr;
  }
 }

 if(defined $arr) {
  $me->header($arr);
  $me->body($arr);
 } 
 else {
  $me->read_header($fd);
  $me->read_body($fd);
 }

 return $me;
}

sub read_body {
 my($me,$fd) = @_;

 $me->body( [ <$fd> ] );
}

sub read_header
{
 my $me = shift;
 my $fd = shift;
 my @arr = ();
 local $_;

 while(<$fd>) {
  last unless(/\A($FIELD_NAME|From )/o || /\A[ \t]+\S/o);
  push(@arr, $_);
 }

 $me->header( \@arr );
}

##
## Public Methods
##

sub empty {
 my $me = shift;
 $me->{Hdrs} = [];
 $me->{Body} = [];
 1;
}

=back

=head2 METHODS

=over 2

=item body()

Returns the body of the message. This is a reference to an array.
Each entry in the array represents a single line in the message.

=cut

sub body {
 my $me = shift;
 my $body = $me->{Body};

 if(@_) {
  my $new = shift;
  $me->{Body} = ref($new) eq 'ARRAY' ? $new : [ $new ];
 }
 return $body;
}

=item header()

Returns a reference to an array of folded header fields.

=cut

sub header {
 my $me = shift;

 if(@_) { 
  my $arr = shift;
  my($line);

  $me->{Hdrs} = [];

  while(scalar(@{$arr}) && $arr->[0] =~ /\A($FIELD_NAME|From )/o) {
   $line = shift @{$arr};
   $line .= shift @{$arr} while(scalar(@{$arr}) && $arr->[0] =~ /\A[ \t]+\S/o);
   $me->add(undef,$line);
  }
 }
 else {
  $me->tidy_headers;
 }
 $me->fold;
}


=item add ( $tag, $line [, $tag, $line [,...]])

Adds a new entry to the header. I<$tag>: I<$line>.

Returns the last line added.

=cut

sub add
{
 my $me = shift;
 my($tag,$line);

 while(@_)
  {
   ($tag,$line) = tag_case(splice(@_,0,2));

   # Must have a tag and text to add
   return undef unless(defined $tag && defined $line);

   push(@{$me->{Hdrs}},$me->fold($line));
  }

 return substr($line, length($tag) + 1);
}

=item replace( $tag, $line [, $tag, $line [,...]] )

Replaces the first header entry I<$tag> with I<$line> or adds a new entry if 
I<$tag> does not exists. 

Returns the last line added.

=cut

sub replace
{
 my $me = shift;
 my($tag,$line,$entry);

TAG:
 while(@_)
  {
   ($tag,$line) = tag_case(splice(@_,0,2));

   # Must have both tag and text.
   #    or maybe delete if line is undef???
   return undef unless(defined $tag && defined $line);

   my $ref;
   my $len = length $tag;
   
   foreach $ref (@{$me->{Hdrs}})
    {
     if(substr($ref,0,$len) eq $tag)
      {
       $ref = $me->fold($line); # Replace, assigning to $ref changes 
				#element in the list
       next TAG;		# Only replace first occurance
      }
    }

   push(@{$me->{Hdrs}}, $me->fold($line));# Add, does not exist
  }

 return substr($line, length($tag) + 1);
}

=item combine( $tag [, $with] )

Combines all occurences of I<$tag> in the header into one entry. If I<$with>
is defined then the lines are joind with I<$with> between them, otherwise a
space is used.

Returns the line.

=cut

sub combine
{
 my $me  = shift;
 my $tag = shift;
 my $with = shift || ' ';
 my $line  = undef;
 my @lines = $me->get($tag);
 
 if(scalar(@lines))
  {
   my ($len, $ref, $new);
 
   ($tag,$line) = tag_case($tag, join($with,@lines));
 
   $len = length $tag;
   $new = $me->fold($line);
 
   foreach $ref (@{$me->{Hdrs}})
    {
     next unless(substr($ref,0,$len) eq $tag);
  
     $ref = defined $new ? $new : undef;
     $new = undef;
    }
 
   $me->tidy_headers;
  }
 
 return defined $line ? substr($line, length($tag) + 1) : undef;
}

=item get ( $tag [, $tag [, ...]] )

Gets tags from the header.

Returns all I<$tag> entries if called in an array context.

Returns the first entry if called in a scalar context.

=cut

sub get
{
 my $me  = shift;
 my @val = ();
 my ($ref,$arg,@tags);

 foreach $arg (@_)
  {
   my $tag = tag_case($arg, undef);
   push(@tags,$tag) if(defined $tag);
  }

 my $pat = join('|',@tags);
 
 foreach $ref (@{$me->{Hdrs}})
  {
   next unless($ref =~ /\A($pat)/);
 
   my $l = substr($ref,1 + length $1);
 
   return $l unless(wantarray); # Short circuit, only want first
 
   push(@val, $l);
  }

 return wantarray ? @val : $val[0];
}

=item delete( $tag )

Deletes all occurences of I<$tag> in the header.

Returns the removed lines.

=cut

sub delete
{
 my $me  = shift;
 my $arg;
 my @val = ();

 foreach $arg (@_)
  {
   my $tag = tag_case($arg, undef);

   my $len = length $tag;
   my $ref;

   foreach $ref (@{$me->{Hdrs}})
    {
     next unless defined $ref;
     if(substr($ref,0,$len) eq $tag)
      {
       my $tmp;
       push(@val, $tmp = $ref);
       $ref = undef;
      }
    }
  }

 $me->tidy_headers;

 return @val;
}


=item print_header( $fd )

=item print_body( $fd )

=item print( $fd )

Print the header, body or whole message to file descriptor I<$fd>. I<$fd>
should be a reference to a GLOB

 $mail->print( \*STDOUT );  # Print message to STDOUT

=cut

sub print_header {
 my $me = shift;
 my $fd = shift || \*STDOUT;
 my $ln;

 foreach $ln (@{$me->header}) { print $fd $ln or return 0; }
 print $fd "\n" or return 0;
}

sub print_body {
 my $me = shift;
 my $fd = shift || \*STDOUT;
 my $ln;

 foreach $ln (@{$me->body}) { print $fd $ln or return 0; }
}

sub print
{
 my $me = shift;
 my $fd = shift || \*STDOUT;

 $me->print_header($fd) && $me->print_body($fd);
}

=back

=head1 UTILITY METHODS

The following methods are more a utility type that a manipulation
type of method.

=over 2

=item remove_sig( [$nlines] )

Attempts to remove a users signature from the body of a message. It does this 
by looking for a line equal to C<'--'> within the last C<$nlines>, default = 10,
if found, removes it and all lines after.
Useful in reply type scripts.

=cut

sub remove_sig
{
 my $me = shift;
 my $nlines = shift || 10;

 my $body = $me->{Body};
 my($line,$i);

 $line = scalar(@{$body});
 return unless($line);

 while($i++ < $nlines && $line--)
  {
   if($body->[$line] =~ /\A--[\r\n]+/)
    {
     splice(@{$body},$line,$i);
     last;
    }
  }
}

=item tidy_body()

Removes all leading and trailing lines from the body that only contain
white spaces.

=cut

sub tidy_body
{
 my $me = shift;

 my $body = $me->{Body};
 my $line;

 if(scalar(@{$body}))
  {
   do { $line = shift @{$body} } while(defined $line && $line =~ /\A\s*\Z/);
   unshift(@{$body}, $line) if(defined $line);

   do { $line = pop @{$body} } while(defined $line && $line =~ /\A\s*\Z/);
   push(@{$body}, $line) if(defined $line);
  }

 return $body;
}

=item fold_length( [$length] )

Sets or gets the length at which the header fields are folded to.

Returns the previous value.

=cut

sub fold_length
{
 my $me  = shift;
 my $len = shift;
 my $old = $me->{FoldLen};

 if(defined $len)
  {
   $me->{FoldLen} = $len > 20 ? $len : 20;
   $me->fold;
  }

 return $old;
}

=item dup()

Create a duplicate of the given Mail::Internet object

=cut

sub dup 
{
 my $me = shift;

 my $copy = bless {}, ref $me;

 $copy->{FoldLen} = $me->{FoldLen};
 $copy->{Body}    = [ @{$me->{Body}} ];
 $copy->{Hdrs}    = [ @{$me->{Hdrs}} ];

 $copy;
}

=item clean_header()

Remove all items which do not have any text element

=cut

sub clean_header 
{
 my $me = shift;

 local $_;

 foreach (@{$me->{Hdrs}}) 
  {
   $_ = undef if(/\A($FIELD_NAME|From )\s*\Z/i);
  }

 $me->tidy_headers;

 1;
}

# Auto loaded methods go after __END__
__END__

sub reply;

=item reply()

Create a new object with header initialised for a reply to the current 
object.

=cut

use Mail::Address;

 sub reply
{
 my $me = shift;
 my %arg = @_;
 my $pkg = ref $me;
 my $indent = $arg{Indent} || ">";
 my @reply = ();

 if(open(MAILHDR,"$ENV{HOME}/.mailhdr")) 
  {
   # User has defined a mail header template
   @reply = <MAILHDR>;
   close(MAILHDR);
  }

 my $reply = $pkg->new(\@reply);

 my($to,$cc,$name,$body,$id);

 # The Subject line

 my $subject = $me->get('Subject') || "";

 $subject = "Re: " . $subject if($subject =~ /\S+/ && $subject !~ /Re:/i);

 $reply->replace('Subject',$subject);

 # Locate who we are sending to
 $to = $me->get('Reply-To')
       || $me->get('From')
       || $me->get('Return-Path')
       || "";

 # Mail::Address->parse returns a list of refs to a 2 element array
 my $sender = (Mail::Address->parse($to))[0];

 $name = $sender->name;
 $id = $sender->address;

 unless(defined $name)
  {
   my $fr = $me->get('From');

   $fr = (Mail::Address->parse($fr))[0] if(defined $fr);
   $name = $fr->name if(defined $fr);
  }

 if($indent =~ /%/) 
  {
   my %hash = ( '%' => '%');
   my @name = grep(do { length > 0 }, split(/[\n\s]+/,$name || ""));
   my @tmp;

   @name = "" unless(@name);

   $hash{f} = $name[0];
   $hash{F} = $#name ? substr($hash{f},0,1) : $hash{f};

   $hash{l} = $#name ? $name[$#name] : "";
   $hash{L} = substr($hash{l},0,1) || "";

   $hash{n} = $name || "";
   $hash{I} = join("",grep($_ = substr($_,0,1), @tmp = @name));

   $indent =~ s/%(.)/defined $hash{$1} ? $hash{$1} : $1/eg;
  }

 $reply->replace('To', $id);

 # Find addresses not to include
 my %nocc = ();
 my $mailaddresses = $ENV{MAILADDRESSES} || "";
 my $addr;

 $nocc{lc $id} = 1;

 foreach $addr (Mail::Address->parse($reply->get('Bcc'),$mailaddresses)) 
  {
   my $lc = lc $addr->address;
   $nocc{$lc} = 1;
  }

 # Who shall we copy this to
 my %cc = ();

 foreach $addr (Mail::Address->parse($me->get('To'),$me->get('Cc'))) 
  {
   my $lc = lc $addr->address;
   $cc{$lc} = $addr->format unless(defined $nocc{$lc});
  }

 $cc = join(', ',values %cc);

 $reply->replace('Cc', $cc);

 # References
 my $refs = $me->get('References') || "";
 my $mid = $me->get('Message-Id');

 $refs .= " " . $mid if(defined $mid);
 $reply->replace('References',$refs);

 # In-Reply-To
 my $date = $me->get('Date');
 my $inreply = "";

 if(defined $mid)
  {
   $inreply  = $mid;
   $inreply .= " from " . $name if(defined $name);
   $inreply .= " on " . $date if(defined $date);
  }
 elsif(defined $name)
  {
   $inreply = $name . "'s message";
   $inreply .= "of " . $date if(defined $date);
  }

 $reply->replace('In-Reply-To', $inreply);

 # Quote the body
 $body  = $reply->body;

 @$body = @{$me->body};		# copy body
 $reply->remove_sig;		# remove signature, if any
 $reply->tidy_body;		# tidy up
 grep(s/\A/$indent/,@$body);	# indent

 # Add references
 unshift @{$body}, (defined $name ? $name . " " : "") . "<$id> writes:\n";

 if(defined $arg{Keep} && 'ARRAY' eq ref($arg{Keep})) 
  {
   # Copy lines from the original
   my $keep;

   foreach $keep (@{$arg{Keep}}) 
    {
     my $ln = $me->get($keep);
     $reply->replace($keep,$ln) if(defined $ln);
    }
  }

 if(defined $arg{Exclude} && 'ARRAY' eq ref($arg{Exclude}))
  {
   # Exclude lines
   $reply->delete(@{$arg{Exclude}});
  }

 # remove empty header lins
 $reply->clean_header;

 $reply;
}

=item add_signature ( [$file] )

Append the contents of C<$file>, or "$ENV{HOME}/.signature" if not given,
to the end of the body text.

=cut

sub add_signature
{
 my $me = shift;
 my $sig = shift || "$ENV{HOME}/.signature";
 local *SIG;

 if(open(SIG,$sig))
  {
   while(<SIG>) { last unless /\A(--)?\s*\Z/; }

   my @sig = ("--\n",$_,<SIG>,"\n");
   map(s/\n?\Z/\n/,@sig);
   push(@{$me->body}, @sig);

   close(SIG);
  }
}

sub smtpsend;

use Carp;
use Mail::Util qw(mailaddress);
use Mail::Address;
use Net::Domain qw(hostname);
use Net::SMTP;

=item smtpsend

Send a Mail::Internet message via SMTP

The message will be sent to all addresses on the To, Cc and Bcc
lines. The SMTP host is found by attempting connections first
to hosts specified in C<$ENV{SMTPHOSTS}>, a colon separated list,
then C<mailhost> and C<localhost>.

=cut

 sub smtpsend 
{
 my $src  = shift;
 my($mail,$smtp,@hosts);

 require Net::SMTP;

 @hosts = qw(mailhost localhost);
 unshift(@hosts, split(/:/, $ENV{SMTPHOSTS})) if(defined $ENV{SMTPHOSTS});

 foreach $host (@hosts) {
  $smtp = eval { Net::SMTP->new($host) };
  last if(defined $smtp);
 }

 croak "Cannot initiate a SMTP connection" unless(defined $smtp);

 $smtp->hello( hostname() );
 $mail = $src->dup;

 $mail->delete('From '); # Just in case :-)

 $mail->replace('X-Mailer', "Perl5 Mail::Internet v" . Mail::Internet->Version);

 # Ensure the mail has the following headers
 # Sender, From, Reply-To

 my($from,$name,$tag);

 $name = (getpwuid($>))[6] || $ENV{NAME} || "";
 while($name =~ s/\([^\(]*\)//) { 1; }

 $from = sprintf "%s <%s>", $name, mailaddress();
 $from =~ s/\s{2,}/ /g;

 foreach $tag (qw(Sender From Reply-To))
  {
   $mail->add($tag,$from) unless($mail->get($tag));
  }

 # An original message should not have any Recieved lines

 $mail->delete('Recieved');

 # Who is it to

 my @rcpt = ($mail->get('To', 'Cc', 'Bcc'));
 my @addr = map($_->address, Mail::Address->parse(@rcpt));

 return () unless(@addr);

 $mail->delete('Bcc'); # Remove blind Cc's
 $mail->clean_header;

 # Send it

 my $ok = $smtp->mail( mailaddress() ) &&
            $smtp->to(@addr) &&
            $smtp->data(join("", @{$mail->header},"\n",@{$mail->body}));

 $smtp->quit;

 $ok ? @addr : ();
}

sub nntppost;

use Mail::Util qw(mailaddress);

=item nntppost()

Post an article via NNTP, require News::NNTPClient.

=cut

require News::NNTPClient;

 sub nntppost
{
 my $mail = shift;

 my $groups = $mail->get('Newsgroups') || "";
 my @groups = split(/[\s,]+/,$groups);

 return () unless @groups;

 my $art = $mail->dup;

 $art->clean_header;
 $art->replace('X-Mailer', "Perl5 Mail::Internet v" . Mail::Internet->Version);

 unless($art->get('From'))
  {
   my $name = $ENV{NAME} || (getpwuid($>))[6];
   while( $name =~ s/\([^\(]*\)// ) {1};
   $art->replace('From',$name . " <" . mailaddress() . ">");
  }

 # Remove these incase the NNTP host decides to mail as well as me
 $art->delete(qw(To Cc Bcc)); 
 $art->clean_header;

 my $news = new News::NNTPClient;
 $news->post(@{$art->header},"\n",@{$art->body});

 my $code = $news->code;
 $news->quit;

 return 240 == $code ? @groups : ();
}

=back

=head1 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head1 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=head1 REVISION

$Revision: 1.17 $

=cut

1; # keep require happy


