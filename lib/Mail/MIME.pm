# Mail::MIME.pm
#
# Copyright (c) 1995 Graham Barr <Graham.Barr@tiuk.ti.com>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mail::MIME;

require Mail::RFC822;

@ISA = qw(Mail::RFC822);

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

=head1 SYNOPSIS

use Mail::MIME;

=head1 DESCRIPTION

This package provides a class object to implement MIME message as
specified in RFC 1521 I<Multipurpose Internet Mail Extensions>

=head1 THIS PACKAGE IS EXPERIMENTAL AND ONLY HERE AS A PLACE HOLDER

=cut

sub read_body {
 my($me,$fd) = @_;

 my $need;
 my $buffer = '';

 if($need = $me->get('Content-Length')) {
  chomp($need);
  read($fd,$buffer,$need);
 }
 else {
  local $/;

  undef $/;

  $buffer = $line . <$fd>;
 }

 $me->body( "" ); # Safety!!
 $me->{MIMEBody} = \$buffer;
}

sub body {
 my $me = shift;
 my $old = $me->{MIMEBody};

 $me->{MIMEBody} = shift if(@_);

 $old;
}

*content =\&body;

sub print_body {
 my $me = shift;
 my $fd = shift || \*STDOUT;

 print $fd ${$me->{MIMEBody}};
}

sub empty {
 my $me = shift;

 $me->Mail::RFC822::empty();

 delete $me->{MIMEBody};
}

