#

package Mail::Mailer;

=head1 NAME

Mail::Mailer - Simple interface to electronic mailing mechanisms 

=head1 SYNOPSIS

    use Mail::Mailer;
    use Mail::Mailer qw(mail);

    $mailer = new Mail::Mailer;

    $mailer = new Mail::Mailer $type, @args;

    $mailer->open(\%headers);

    print $mailer $body;

    $mailer->close;


=head1 DESCRIPTION

Sends mail using any of the built-in methods.  You can alter the
behaviour of a method by passing C<$command> to the C<new> method.

=over 4

=item C<mail>

Use the Unix system C<mail> program to deliver the mail.  C<$command>
is the path to C<mail>.

=item C<sendmail>

Use the C<sendmail> program to deliver the mail.  C<$command> is the
path to C<sendmail>.

=item C<test>

Used for debugging, this calls C</bin/echo> to display the data.  No
mail is ever sent.  C<$command> is ignored.

=back

C<Mail::Mailer> will search for executables in the above order. The
default mailer will be the first one found. In the case of C<mail>
Mail::Mailer will search for C<mail>, C<mailx> and C<Mail>.

=head2 ARGUMENTS

C<new> can optionally be given a C<$command> and C<$type>.  C<$type>
is one C<sendmail>, C<mail>, ... given above.  The meaning of
C<$command> depends on C<$type>.

C<open> is given a reference to a hash.  The hash consists of key and
value pairs, the key being the name of the header field (eg, C<To>),
and the value being the corresponding contents of the header field.
The value can either be a scalar (eg, C<gnat@frii.com>) or a reference
to an array of scalars (C<eg, [gnat@frii.com, Tim.Bunce@ig.co.uk]>).

=head1 TO DO

Assist formatting of fields in ...::rfc822:send_headers to ensure
valid in the face of newlines and longlines etc.

Secure all forms of send_headers() against hacker attack and invalid
contents. Especially "\n~..." in ...::mail::send_headers.

=head1 SEE ALSO

Mail::Send

=head1 AUTHORS

Tim Bunce <Tim.Bunce@ig.co.uk>, with a kick start from Graham Barr
<bodg@tiuk.ti.com>. With contributions by Gerard Hickey <hickey@ctron.com>
For support please contact comp.lang.perl.misc.
Small fix and documentation by Nathan Torkington <gnat@frii.com>.

=cut

use Carp;
use FileHandle;
use Symbol;
use vars qw(@ISA $VERSION $MailerBinary $MailerType %Mailers @Mailers);

$VERSION = "1.08";
sub Version { $VERSION }

@ISA = qw(FileHandle);

# Suggested binaries for types?  Should this be handled in the object class?
@Mailers = (
    'mail'	=> 	'mail',			# Body on stdin with tilde escapes
    'sendmail'	=>	'/usr/lib/sendmail',	# Headers-blank-Body all on stdin
    'smtp'	=> 	'telnet',
    'test'	=> 	'test'
);

push(@Mailers, split(/:/,$ENV{PERL_MAILERS})) if $ENV{PERL_MAILERS};
%Mailers = @Mailers;

$MailerBinary = undef;

# On solaris mail does not except ~ escapes, you must use mailx

use Config;

if(is_exe('mailx')) {
    my $cmd = 'mailx';
    my $osname = $Config{osname};
    if($osname =~ /solaris/io) {
	$cmd .= " -~";
    }
    elsif($osname =~ /linux/io) {
	$cmd .= " -i";
    }
    $Mailers{mail} = $cmd;
}
elsif(is_exe('Mail')) {
    $Mailers{mail} = 'Mail';
}

# does this really need to be done? or should a default mailer be specfied?
my $i;
foreach $i ( 0..$#Mailers ) {
    next if $i % 2;
    $MailerType = $Mailers[$i];
    my $binary;
    if ($binary=is_exe($Mailers{$MailerType})) {
	$MailerBinary = $binary;
	last;
    }
}

sub import {
    shift;

    if(@_) {
	my $type = shift;
	my $exe = shift || $Mailers{$type};

        carp "Cannot locate '$exe'"
            unless is_exe($exe);

        $MailerType = $type;
        $Mailers{$MailerType} = $exe;
    }
}

sub to_array {
    my($self, $thing) = @_;
    if (ref($thing)) {
	return @$thing;
    } else {
	return ($thing);
    }
}

sub is_exe {
    my $exe = shift;
    my $dir;
    # remove any options
    my $name = ($exe =~ /(\S+)/)[0];
    # check for absolute or relative path
    return ($exe) if (-x $name and ! -d $name and $name =~ m:/:);
    foreach $dir (split(/:/, $ENV{PATH})) {
	return "$dir/$exe" if (-x "$dir/$name" && ! -d "$dir/$name");
    }
    0;
}

sub new {
    my($class, $type, @args) = @_;
    my ($exe) = is_exe ($Mailers{$type});

    $exe  = $MailerBinary  unless $exe;
    croak "No mailer type specified (and no default available), thus can not find executable program."
	unless $exe;

    $type = $MailerType unless $type;
    croak "Mailer '$type' not known, please specify correct type"
	unless $type;

    local($glob) = gensym;	# Make glob for FileHandle and attributes

    %{*$glob} = (Exe 	=> $exe,
		 Args	=> [ @args ]
		);
    
    $class = "Mail::Mailer::$type";
    bless $glob, $class;
}


sub open {
    my($self, $hdrs) = @_;
    my $exe = *$self->{Exe} || Carp::croak "$self->open: bad exe";
    my $args = *$self->{Args};
    my @to = $self->who_to($hdrs);
    
    $self->close;	# just in case;

    # Fork and start a mailer
    open($self,"|-") || $self->exec($exe, $args, \@to) || die $!;

    # Set the headers
    $self->set_headers($hdrs);

    # return self (a FileHandle) ready to accept the body
    $self;
}


sub exec {
    my($self, $exe, $args, $to) = @_;
    # Fork and exec the mailer (no shell involved to avoid risks)
    my @exe = split(/\s+/,$exe);
    exec(@exe, @$args, @$to);
}

sub can_cc { 1 }	# overridden in subclass for mailer that can't

sub who_to {
    my($self, $hdrs) = @_;
    my @to = $self->to_array($hdrs->{To});

    if (!$self->can_cc) {  # Can't cc/bcc so add them to @to
	push(@to, $self->to_array($hdrs->{Cc})) if $hdrs->{Cc};
	push(@to, $self->to_array($hdrs->{Bcc})) if $hdrs->{Bcc};
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
}

##
##
##

package Mail::Mailer::rfc822;
@ISA = qw(Mail::Mailer);

sub set_headers {
    my $self = shift;
    my $hdrs = shift;
    local($\)="";
    foreach(keys %$hdrs) {
	next unless m/^[A-Z]/;
	print $self "$_: ", join(",", $self->to_array($hdrs->{$_})), "\n";
    }
    print $self "\n";	# termitane headers
}

##
##
##

package Mail::Mailer::sendmail;
@ISA = qw(Mail::Mailer::rfc822);


sub exec {
    my($self, $exe, $args, $to) = @_;
    # Fork and exec the mailer (no shell involved to avoid risks)

    # We should always use a -t on sendmail so that Cc: and Bcc: work
    #  Rumor: some sendmails may ignore or break with -t (AIX?)
    exec(( $exe, '-t', @$args, @$to ));
}

##
##
##

package Mail::Mailer::mail;
@ISA = qw(Mail::Mailer);

my %hdrs = qw(Cc ~c Bcc ~b Subject ~s);

sub set_headers {
    my $self = shift;
    my $hdrs = shift;
    my($k,$v);

    while(($k,$v) = each %hdrs) {
	print $self join(" ",$v, $self->to_array($hdrs->{$k})), "\n"
		if defined $hdrs->{$k};
    }
}

##
##
##

package Mail::Mailer::smtp;		# just for fun
@ISA = qw(Mail::Mailer::rfc822);

sub exec {
    my($self, $exe, $args, $to) = @_;
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

##
##
##

package Mail::Mailer::test;
@ISA = qw(Mail::Mailer::rfc822);

sub can_cc { 0 }

sub exec {
    my($self, $exe, $args, $to) = @_;
    exec('sh', '-c', "echo to: " . join(" ",@{$to}) . "; cat");
}

1;

