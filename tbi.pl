#!/usr/bin/env perl
use strict;
use warnings;
use lib '.';
use BigInteger;
use Test::More;

ok(BigInteger->new( 34)
 + BigInteger->new( 78) ==
   BigInteger->new(112), 'add two positives');

ok(BigInteger->new(-34)
 + BigInteger->new(-78) ==
   BigInteger->new(-112), 'add two negatives');

ok(BigInteger->new(34)
 * BigInteger->new(78) ==
   BigInteger->new(2652), 'multiply two positives');

ok(BigInteger->new(78)
 * BigInteger->new(34) ==
   BigInteger->new(2652), 'multiply two positives swapped');

ok(BigInteger->new(-34)
 * BigInteger->new(-78) ==
   BigInteger->new(2652), 'multiply two negatives');

ok(BigInteger->new(34)
 * BigInteger->new(-78) ==
   BigInteger->new(-2652), 'multiply positive and a negative');

ok(BigInteger->new(-34)
 * BigInteger->new(78) ==
   BigInteger->new(-2652), 'multiply negative and a positive');

ok(BigInteger->new(4)
* $BigInteger::zero == $BigInteger::zero, 'times zero 1');

ok($BigInteger::zero *
    BigInteger->new(4)
== $BigInteger::zero, 'times zero 2');

ok(BigInteger->new(78)->compare(
   BigInteger->new(34)) == 1,    'compare 1');

ok(BigInteger->new(178)->compare(
   BigInteger->new(34)) == 1,    'compare 2');

ok(BigInteger->new(34)->compare(
    BigInteger->new(78)) == -1, 'compare 3');

ok(BigInteger->new(-34)->compare(
   BigInteger->new(-78)) == 1, 'compare 4');

ok(BigInteger->new(98765)
 - BigInteger->new(12345) ==
   BigInteger->new(86420), 'subtract with no borrowing');

ok(BigInteger->new(90765)
 - BigInteger->new( 9876) ==
   BigInteger->new(80889), 'subtract with borrowing 1');

ok(BigInteger->new(90005)
 - BigInteger->new( 9876) ==
   BigInteger->new(80129), 'subtract with borrowing 2');

ok(BigInteger->new( 9)
 - BigInteger->new(-8) == 
   BigInteger->new(17), 'subtract negative from positive');

ok(BigInteger->new( -9)
 - BigInteger->new(  8) == 
   BigInteger->new(-17), 'subtract positive from negative');

ok(BigInteger->new(-9)
 - BigInteger->new(-8) == 
   BigInteger->new(-1), 'subtract negative from negative');

ok(BigInteger->new(9)
 - BigInteger->new(9) == 
   BigInteger->new(0), 'subtract equals');

my $x = BigInteger->new(151);
my $y = BigInteger->new(16);
my ($quo, $rem) = $x->divide($y);
ok($quo == BigInteger->new(9)
&& $rem == BigInteger->new(7), 'divide 1');

$x = BigInteger->new(15);
$y = BigInteger->new(161);
($quo, $rem) = $x->divide($y);
ok($quo == BigInteger->new(0)
&& $rem == BigInteger->new(15), 'divide 2');

$x = BigInteger->new(2048);
$y = BigInteger->new(2);
($quo, $rem) = $x->divide($y);
ok($quo == BigInteger->new(1024)
&& $rem == BigInteger->new(0), 'divide 3');

# handle the different signs with division
my $div = <<'EOD';
 39   5   7   4
 39  -5  -7   4
-39   5  -8   1  # 5-4
-39  -5   8   1  # 5-4

  5  39   0   5
  5 -39   0   5
 -5  39  -1  34
 -5 -39   1  34
EOD
open my $din, '<', \$div
    or die "cannot open heredoc div\n";
LINE:
while (my $line = <$din>) {
    chomp $line;
    $line =~ s{[#].*}{}xms;
    if ($line !~ m{\S}xms) {
        next LINE;
    }
    my ($a, $b, $c, $d) = $line =~ m{([-]?\d+)}xmsg;
    my $x = BigInteger->new($a);
    my $y = BigInteger->new($b);
    my ($quo, $rem) = $x->divide($y);
    ok($quo == BigInteger->new($c)
    && $rem == BigInteger->new($d), "divide $a by $b");
}
close $din;

my $add_sub = <<'EOT';
 5 +  6 =  11
-5 +  6 =   1
 5 + -6 =  -1
-5 + -6 = -11

 5 -  6 =  -1
-5 -  6 = -11
 5 - -6 =  11
-5 - -6 =   1

 6 -  5 =   1
 6 - -5 =  11
-6 -  5 = -11
-6 - -5 =  -1
EOT
#
# read the above lines and create tests
#
open my $in, '<', \$add_sub
    or die "cannot open heredoc string EOT\n";
LINE:
while (my $line = <$in>) {
    chomp $line;
    next LINE unless $line =~ m{\S}xms;
    my ($x, $o, $y, $z) = $line =~ m{
        \A \s*
        ([\d\-]+)    # $x
        \s+
        ([+-])       # $o
        \s+
        ([\d\-]+)    # $y
        \s+ [=] \s+  # =
        ([\d\-]+)    # $z
        \s* \z
    }xms;
    my $bx = BigInteger->new($x);
    my $by = BigInteger->new($y);
    my $bz = BigInteger->new($z);
    if ($o eq '+') {
        ok($bx + $by == $bz, $line);
    }
    else {
        ok($bx - $by == $bz, $line);
    }
}
close $in;

# random testing
# get two random numbers in the range -10^3 to 10^3
# add, subtract, and multiply them as Perl scalars
# and then as BigIntegers.
# do these two things many times.
# the number of times they disagree should be zero
#
my $pow = 10**4;
my $ntests = 200;
my $nfail = 0;
for my $nt (1 ... $ntests) {
    my $x = int(rand 2*$pow) - $pow;
    my $y = int(rand 2*$pow) - $pow;
    my $a = $x + $y;
    my $s = $x - $y;
    my $m = $x * $y;
    my $bx = BigInteger->new($x);
    my $by = BigInteger->new($y);
    my $ba = $bx + $by;
    my $bs = $bx - $by;
    my $bm = $bx * $by;
    my ($bq, $br);
    if ($y != 0) {
        ($bq, $br) = $bx->divide($by);
        if ($bq*$by + $br == $bx
            && ($BigInteger::zero <= $br && $br < $by->abs)
        ) {
            ; # ok
        }
        else {
            print "fail: divide $bx by $by = $bq remainder $br\n";
            ++$nfail;
        }
    }
    if ("$a" ne "$ba"
        ||
        "$s" ne "$bs"
        ||
        "$m" ne "$bm"
        ||
        ($x <=> $y) != ($bx <=> $by)
    ) {
        print "$x, $y, add $a $ba, sub $s $bs, mul $m $bm\n";
        print "<=> ", ($x <=> $y), " ", ($bx <=> $by), "\n";
        <STDIN>;
        ++$nfail;
    }
}
ok($nfail == 0, "$ntests random tests");

done_testing();
