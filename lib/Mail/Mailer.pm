#

package Mail::Mailer;

=head1 NAME

Mail::Mailer - Simple interface to electronic mailing mechanisms 

=head1 SYNOPSIS

    require Mail::Mailer;

    $mailer = new Mail::Mailer;

    $mailer = new Mail::Mailer $command, $type;

    $mailer->open(\%headers);

    print $mailer $body;

    $mailer->close;


=head1 DESCRIPTION

$Revision: 1.4 $

=head1 TO DO

Assist formatting of fields in ...::rfc822:send_headers to ensure
valid in the face of newlines and longlines etc.

Secure all forms of send_headers() against hacker attack and invalid
contents. Especially "\n~..." in ...::mail::send_headers.

=head1 SEE ALSO

Mail::Send

=head1 AUTHORS

Tim Bunce <Tim.Bunce@ig.co.uk>, with a kick start from Graham Barr
<bodg@tiuk.ti.com>. For support please contact comp.lang.perl.misc.

=cut

use Carp;
use FileHandle;

$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

@ISA = qw(FileHandle);

@Mailers = (
    '/usr/lib/sendmail'	=> 'sendmail',	# Headers-blank-Body all on stdin
    'mail'		=> 'mail',	# Body on stdin with tilde escapes
    'telnet'		=> 'smtp',
    'test'		=> 'test',
);
push(@Mailers, split(/:/,$ENV{PERL_MALIERS})) if $ENV{PERL_MALIERS};
%Mailers = @Mailers;

$MailerBinary = undef;
$gensym = "SYM000";

foreach( 0..@Mailers ) {
    next if $_ % 2;
    my $binary = $Mailers[$_];
    if (is_exe($binary)) {
	$MailerBinary = $binary;
	last;
    }
}

sub gensym {
    *{"Mail::Mailer::" . $gensym++};
}
sub ungensym {
    local($x) = shift;
    $x =~ s/.*:://;
    delete $Mail::Mailer::{$x};
}
sub is_exe {
    my $name = shift;
    my $dir;
    # check for absolute or relative path
    return (-x $name && ! -d $name) if ($name =~ m:/:);
    foreach $dir (split(/:/, $ENV{PATH})) {
	return 1 if (-x "$dir/$name" && ! -d "$dir/$name");
    }
    0;
}

sub new {
    my($class, $exe, $type, @args) = @_;

    $exe  = $MailerBinary  unless $exe;
    croak "No mailer program specified (and no default available)" unless $exe;

    $type = $Mailers{$exe} unless $type;
    croak "Mailer '$exe' not known, please specify type" unless $type;

    local($glob) = &gensym;	# Make glob for FileHandle and attributes
    %{*$glob} = (Exe => $exe);
    $class = "Mail::Mailer::$type";
    bless \$glob, $class;
}


sub open {
    my($self, $hdrs) = @_;
    my $exe = *$self->{Exe} || Carp::croak "$self->open: bad exe";
    my @to  = $self->who_to($hdrs);

    $self->close;	# just in case;

    # Fork and start a mailer
    open($self,"|-") || $self->exec($exe, @to) || die $!;

    # Set the headers
    $self->set_headers($hdrs);

    # return self (a FileHandle) ready to accept the body
    $self;
}


sub exec {
    my($self, $exe, @to) = @_;
    # Fork and exec the mailer (no shell involved to avoid risks)
    exec($exe, @to);
}

sub can_cc { 1 }	# overridden in subclass for mailer that can't

sub who_to {
    my($self, $hdrs) = @_;
    my @to  = @{$hdrs->{To}};
    if (!$self->can_cc) {  # Can't cc/bcc so add them to @to
	push(@to, @{$hdrs->{Cc}})  if $hdrs->{Cc};
	push(@to, @{$hdrs->{Bcc}}) if $hdrs->{Bcc};
    }
    @to;
}

sub epilogue {
    # This could send a .signature, also see ::smtp subclass
}

sub close {
    my($self, @to) = @_;
    if (fileno($self)) {
	$self->epilogue;
	close($self)
    }
}


sub DESTROY {
    my $self = shift;
    $self->close;
    ungensym($self);
}




package Mail::Mailer::rfc822;
@ISA = qw(Mail::Mailer);

sub set_headers {
    my $self = shift;
    my $hdrs = shift;
    local($\)="";
    foreach(keys %$hdrs) {
	next unless m/^[A-Z]/;
	print $self "$_: @{$hdrs->{$_}}\n";
    }
    print $self "\n";	# termitane headers
}


package Mail::Mailer::sendmail;
@ISA = qw(Mail::Mailer::rfc822);


package Mail::Mailer::mail;
@ISA = qw(Mail::Mailer);

sub set_headers {
    my $self = shift;
    my $hdrs = shift;
    print $self "~c @{$hdrs->{Cc}}\n"  if defined $hdrs->{Cc};
    print $self "~b @{$hdrs->{Bcc}}\n" if defined $hdrs->{Bcc};
    print $self "~s @{$hdrs->{Subject}}\n" if defined $hdrs->{Subject};
}


package Mail::Mailer::smtp;		# just for fun
@ISA = qw(Mail::Mailer::rfc822);

sub exec {
    my($self, $exe, @to) = @_;
    exec($exe, 'localhost', 'smtp');
}

sub set_headers {
    my $self = @_;
    Carp::croak "Not implemented yet.";
    # Now send the headers
    $self->Mail::Mailer::rfc822::set_headers();
}

sub epilogue {
    print {$_[0]} ".\n";

}

package Mail::Mailer::test;
@ISA = qw(Mail::Mailer::rfc822);

sub can_cc { 0 }

sub exec {
    my($self, $exe, @to) = @_;
    exec('sh', '-c', "echo to: @to; cat");
}

