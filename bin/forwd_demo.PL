# This -*- perl -*- script makes the forwd_demo script
# $Id: forwd_demo.PL,v 1.1 1995/10/18 09:13:28 a909937 Exp $

$script = "bin/forwd_demo";

use Config;
unlink($script);
open MIR, ">$script" or die "open for writing $script: $!";
print MIR "#!$Config{'scriptdir'}/perl -w\n";
print MIR <DATA>; 
chmod(0755, $script);

__DATA__
use lib qw(./blib ./lib);
use Mail::RFC822;

@mail = <>;

$mail = Mail::RFC822->new(\@mail);

$mail->remove_sig;
$mail->tidy_body;

@reply = ();
if(open(HDR,"$ENV{HOME}/.mailhdr")) {
 @reply = <HDR>;
 close(HDR);
}

$rply = Mail::RFC822->new(\@reply);

$subject = $mail->get('Subject');

$rply->replace('To', "");
$rply->replace('Cc', "");
$rply->replace('Subject',$subject);

$rply->body($body = $mail->body);

unshift @{$body},"---------- Begin Included Message ----------\n",
push    @{$body},"----------- End Included Message -----------\n";

$file = "/tmp/reply.$$";

open(FILE,">$file") || die "Cannot open $file:$!\n";

$rply->print(\*FILE);

close(FILE);

$editor = $ENV{"EDITOR"} || "ned -S";

warn "$editor :$!\n" if (system("$editor $file"));

unlink($file,$file . '%');

exit 0;

