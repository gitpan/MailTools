#!perl -w

require Mail::Internet;

print "1..3\n";

$head = <<EOF;
From from_
To: to
From: from
Subject: subject
EOF

$body = <<EOF;
one

From foo
four

>From bar
seven
EOF

$mail = "$head\n$body";
($mbox = $mail) =~ s/^(>*)From /$1>From /gm;
$mbox =~ s/^>From /From / or die;
$mbox .= "\n";
@mail = map { "$_\n" } split /\n/, $mail;

sub ok {
    my ($n, $result, @info) = @_;
    if ($result) {
    	print "ok $n\n";
    }
    else {
    	for (@info) {
	    s/^/# /mg;
	}
    	print "not ok $n\n", @info;
	print "\n" if @info && $info[-1] !~ /\n$/;
    }
}

ok 1, $i = new Mail::Internet \@mail, Modify => 0;
ok 2, $i->as_string eq $mail, $i->as_string;
ok 3, $i->as_mbox_string eq $mbox, $i->as_mbox_string;
