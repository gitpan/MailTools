# This -*- perl -*- script makes the forwd_demo script
# $Id: send_demo.PL,v 1.1 1995/10/18 09:13:28 a909937 Exp $

$script = "bin/send_demo";

use Config;
unlink($script);
open MIR, ">$script" or die "open for writing $script: $!";
print MIR "#!$Config{'scriptdir'}/perl -w\n";
print MIR <DATA>; 
chmod(0755, $script);

__DATA__
use lib qw(./lib);
use Mail::RFC822;

sub unalias
{
 my $aliases = shift;
 local(@aliases) = @_;
 local($alias);
 local(@ids,%done);

 @ids  = ();
 %done = ();

 while($alias = shift(@aliases))
  {
   next if(defined $done{$alias});
   $done{$alias} = 1;

   (defined $aliases->{$alias}) ? unshift(@aliases, @{$aliases->{$alias}})
                                : push(@ids, $alias);
  }

 return @ids;
}

sub read_mailrc
{
 my %aliases = ();

 if(open(MAILRC,"$ENV{HOME}/.mailrc"))
  {
   while(<MAILRC>)
    {
     next unless(/^\s*(alias|group)\s+(\S+)\s+(.*)/);
     ($group,$who) = ($2,$3);
     
     @{$aliases{$group}} = split(/[, \n]+/,$who);
    }
   close(MAILRC);
  }

 return \%aliases;
}

sub print_signature
{
 if(open(SIG,"$ENV{HOME}/.signature"))
  {
   print "--\n";
   while(<SIG>) { last unless /\A(--)?\s*\Z/; }
   print;
   print while(<SIG>);
   print "\n";
   close(SIG);
  }
}

sub expand_ids
{
 local($aliases,$mail,$tag) = @_;
 local(@ids,@parts);

 @ids = Mail::Address->parse($mail->get($tag));
 @parts = ();

 if(scalar(@ids)) {
  my $id;
  foreach $id (@ids) {
   my $addr = $id->address;
   my @addrs = ();

   if(defined $aliases->{$addr}) {
    @addrs = unalias($aliases, $addr);
    $id->address($addrs[0]) if(scalar(@addrs) == 1);
   }

   push(@parts,(scalar(@addrs) > 1) ? @addrs : $id->format);
  }
 }

 scalar(@parts) ? $mail->replace($tag, join(", ",@parts))
                : $mail->delete($tag);

}

sub process_IMS
{
 local $text  = shift;
 local $mail    = Mail::RFC822->new();
 local %aliases = ();
 local @IMSids = ();
 local @MIMIoptions = ();

 while($_ = shift @{$text}) {
  local $more = 0;
  chomp;
  foreach $id (split(/[, ]+/)) {
   $id = lc $id;

   next if($id eq "msg"); 
   next if($id =~ /\A\d+\Z/); # ignore cc & div info

   if($id =~ /\A(\w+)=(\w*)?\Z/) {
    $opt = $1;
    $val = $2 || "yes";

    push(@MIMIoptions, "NONTIER") if($opt eq "nontier" && $val eq "yes");

    next;
   }

   push(@MIMIoptions, "SECURE")   && next if($id eq "sendsc");
   push(@MIMIoptions, "INTERNAL") && next if($id eq "sendint");

   if($id eq "&") {
    $more = 1;
    next ;
   }

   push(@IMSids, $id . '@mimi.ti.com');
  }

  last unless $more;
 }

 $mail->add('To',join(", ",@IMSids));
 $mail->add('X-MIMI-Options',join(", ",@MIMIoptions)) if(@MIMIoptions);

 $mail->body($text);

 $mail;
}

###
### Main program
###

@msgtext = <>;

die "No message text\n" unless scalar(@msgtext);


$mail = ($msgtext[0] =~ /^MSG/i) ? process_IMS(\@msgtext)
                                 : Mail::RFC822->new(\@msgtext);

$aliases = read_mailrc; # Read mailrc for aliases

# Expand aliases

foreach $tag (qw(To Cc Bcc)) { expand_ids($aliases,$mail,$tag); }

# open(STDOUT,"|/usr/lib/sendmail -i -t") || die("Cannot re-direct stdout\n");

$mail->print;

print_signature;

exit;


