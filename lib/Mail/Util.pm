# Mail::Util.pm
#
# Copyright (c) 1995 Graham Barr <bodg@tiuk.ti.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mail::Util;

$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }


=head1 SYNOPSIS

use Mail::Util qw( ... );

=head1 DESCRIPTION

This package provides several mail related utility functions. Any function
required must by explicitly listed on the use line to be exported into
the calling package.

=cut

require 5.000;
require AutoLoader;
require Exporter;
require POSIX;
use Carp;

@ISA = qw(Exporter AutoLoader);

@EXPORT_OK = qw(read_mbox maildomain mailaddress);

1;

__END__

=head2 read_mbox( $file )

Read C<$file>, a binmail mailbox file, and return a list of Mail::RFC822
objects.

=cut

sub read_mbox {
 my $file  = shift;
 my $fd    = FileHandle->new($file,"r") || croak "cannot open '$file': $!\n";
 my @mail  = ();
 my $mail  = [];
 my $blank = 1;

 local $_;

 while(<$fd>) {
  if($blank && /\AFrom /) {
   push(@mail, $mail) if scalar(@{$mail});
   $mail = [ $_ ];
   $blank = 0;
  }
  else {
   $blank = m#\A\Z#o ? 1 : 0;
   push(@{$mail}, $_);
  }
 }

 push(@mail, $mail) if scalar(@{$mail});

 $fd->close;

 return wantarray ? @mail : \@mail;
}

=head2 maildomain()

Attempt to determine the current uers mail domain string via the following
methods

 Look for a sendmail.cf file and extract DH paramter
 Look for a smail config file and usr the first host defined in hostname(s)
 Try an SMTP connect (if Net::SMTP exists) first to mailhost then localhost
 Use Sys::Hostname . "." . Sys::Domainname

=cut

sub maildomain {

 ##
 ## return imediately if already found
 ##

 return $domain if(defined $domain);

 ##
 ## Try sendmail config file if exists
 ##

 local *CF;
 my @sendmailcf = qw(/etc /etc/sendmail /etc/ucblib /etc/mail /usr/lib);

 my $config = (grep(-r, map("$_/sendmail.cf", @sendmailcf)))[0];

 if(defined $config && open(CF,$config)) {
  while(<CF>) {
   if(/\ADH(\S+)/) {
    $domain = $1;
    last;
   }
  }
  close(CF);
  return $domain if(defined $domain);
 }

 ##
 ## Try smail config file if exists
 ##

 if(open(CF,"/usr/lib/smail/config")) {
  while(<CF>) {
   if(/\A\s*hostnames?\s*=\s*(\S+)/) {
    $domain = (split(/:/,$1))[0];
    last;
   }
  }
  close(CF);
  return $domain if(defined $domain);
 }

 ##
 ## Try a SMTP connection to 'mailhost'
 ##

 if(eval "require Net::SMTP") {

  my $smtp = Net::SMTP->new("mailhost");
  
  $smtp = Net::SMTP->new("localhost") unless(defined $smtp);

  if(defined $smtp) {
   $domain = $smtp->domain;
   $smtp->quit;
  }
 }

 ##
 ## Use internet domain name, if it can be found
 ##

 unless(defined $domain) {
  if(eval "require Sys::Domainname" && eval "require Sys::Hostname") {
   my $host = (split(/\./,Sys::Hostname::hostname()))[0];

   $domain = $host . "." . Sys::Domainname::domainname();
  }
 }

 return $domain;
}

=head2 mailaddress()

Return a guess at the current users mail address.

=cut

sub mailaddress {

 ##
 ## Return imediately if already found
 ##

 return $mailaddress if(defined $mailaddress);

 ##
 ## first look for $ENV{MAILADDRESS}
 ##

 return $mailaddress = $ENV{MAILADDRESS} if(defined $ENV{MAILADDRESS});

 ##
 ## Default to user name and maildomain
 ##

 maildomain() unless(defined $domain);

 my $user = $ENV{USER} || $ENV{LOGNAME} || "";

 $mailaddress = $user . "@" . $domain;
}

=head1 AUTHOR

Graham Barr <bodg@tiuk.ti.com>

=head1 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=head1 REVISION

$Revision: 1.5 $

=cut

