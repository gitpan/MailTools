# This -*- perl -*- script makes the forwd_demo script
# $Id: rplyto_demo.PL,v 1.1 1995/10/18 09:13:28 a909937 Exp $

$script = "bin/rplyto_demo";

use Config;
unlink($script);
open MIR, ">$script" or die "open for writing $script: $!";
print MIR "#!$Config{'scriptdir'}/perl -w\n";
print MIR <DATA>; 
chmod(0755, $script);

__DATA__
use lib qw(./lib);
use Mail::RFC822;
use Getopt::Std;

getopts('as');

$reply_all = (defined $opt_s) ? 0 : 1;

@line = <>;

$mail = Mail::RFC822->new(\@line);
$rply = $mail->reply();

$rply->delete("Cc") unless($reply_all);

$file = "/tmp/reply.$$";

open(\*file,">$file") || die "Cannot open $file:$!\n";

$rply->print(\*file);

close(\*file);

$editor = $ENV{"EDITOR"} || die "\$EDITOR not defined\n";

warn "$editor :$!\n" if (system("$editor $file"));

# Cleanup
unlink($file,$file . '%',$file . '~');

exit 0;

