require Mail::Header;

print "1..16\n";

$h = new Mail::Header;

$t = 0;

$h->add('test',"a test header");
$h->add('test',"a longer test header");
$h->add('test',"an even longer test header");

$h->print;

print "not "
	unless $h->get('test',0) eq "a test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',1) eq "a longer test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',2) eq "an even longer test header\n";
printf "ok %d\n",++$t;

$h->fold(30);

print "not "
	unless $h->get('test',0) eq "a test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',1) eq "a longer test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',2) eq "an even longer test\n    header\n";
printf "ok %d\n",++$t;

$h->fold(20);

print "not "
	unless $h->get('test',0) eq "a test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',1) eq "a longer\n    test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',2) eq "an even\n    longer test\n    header\n";
printf "ok %d\n",++$t;

$h->unfold;

print "not "
	unless $h->get('test',0) eq "a test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',1) eq "a longer test header\n";
printf "ok %d\n",++$t;

print "not "
	unless $h->get('test',2) eq "an even longer test header\n";
printf "ok %d\n",++$t;

$head = <<EOF;
From from_
To: to
From: from
Subject: subject
EOF
$body = "body\n";
$mail = "$head\n$body";
@mail = map { "$_\n" } split /\n/, $mail;

print "not "
	unless $h = new Mail::Header \@mail, Modify => 0;
printf "ok %d\n",++$t;

print "not "
	unless $h->as_string eq $head;
printf "ok %d\n",++$t;

$headin = <<EOF;
Content-Type: multipart/mixed;
       boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"
Content-Type: multipart/mixed;
       boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hkjhgkfhgfhgf"hfkjdhf fhjf fghjghf fdshjfhdsj" hgjhgfjk
Content-Type: multipart/mixed;
       boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hkjhg kfhgfhgf"hfkjdhf fhjf fghjghf fdshjfhdsj" hgjhgfjk
Content-Type: multipart/mixed;
       boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hhhhhhhhhhhhhhhhhhhhhhhhh fjsdhfkjsd fhdjsfhkj
Content-Type: multipart/mixed;
       boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE" abc def ghfdgfdsgj fdshfgfsdgfdsg hfsdgjfsdg fgsfgjsg
EOF
$headout = <<EOF;
Content-Type: multipart/mixed;
    boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"
Content-Type: multipart/mixed;
    boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hkjhgkfhgfhgf"hfkjdhf fhjf fghjghf fdshjfhdsj"
    hgjhgfjk
Content-Type: multipart/mixed;
    boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hkjhg
    kfhgfhgf"hfkjdhf fhjf fghjghf fdshjfhdsj"
    hgjhgfjk
Content-Type: multipart/mixed;
    boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"hhhhhhhhhhhhhhhhhhhhhhhhh
    fjsdhfkjsd fhdjsfhkj
Content-Type: multipart/mixed;
    boundary="---- =_NextPart_000_01BDBF1F.DA8F77EE"
    abc def ghfdgfdsgj fdshfgfsdgfdsg hfsdgjfsdg fgsfgjsg
EOF
@mail = map { "$_\n" } split /\n/, $headin;

print "not "
	unless $h = new Mail::Header \@mail, Modify => 1;
printf "ok %d\n",++$t;

print "not "
	unless $h->as_string eq $headout;
printf "ok %d\n",++$t;
