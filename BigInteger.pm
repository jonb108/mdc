use strict;
use warnings;

#
# there are certainly more efficient and concise
# ways of doing this.  the aim here is to be correct
# and simple.
#
# One cool thing here is that
# (after initialization during module loading)
# we do not rely on addition or subtraction of numeric scalars
# (even with single digits). search for +!
#
# we DO rely on the _string_ comparison of the digits 0-9

package BigInteger;
use Moo;
use Carp qw/
    croak
/;
$Carp::Verbose = 1;

use overload 
    '+'   => 'plus',
    '-'   => 'subtract',
    '*'   => 'times',
    '/'   => 'divide',
    '=='  => 'equal',
    '!='  => 'not_equal',
    '>'   => 'greater_than',
    '<'   => 'less_than',
    '<=>' => 'compare',
    '""'  => 'as_string'
    ;

# an array of digits 0-9
has 'digits' => (
    is => 'ro',
    isa => sub {
        my $aref = shift;
        croak unless ref $aref eq 'ARRAY';
        for my $d (@$aref) {
            croak unless '0' le $d && $d le '9';
        }
    },
    required => 1,
);

has 'sign' => (
    is => 'ro',
    isa => sub {
        my $s = shift;
        croak unless ($s eq '+' || $s eq '-');
    },
);

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    if (@args == 0 || ! defined $args[0]) {
        croak "missing numeric argument";
    }
    if (@args == 1 && !ref $args[0]) {
        my $arg = $args[0];
        $arg =~ s{\A 0+([0-9])}{$1}xms;     # trim leading zeroes
        croak "illegal number: $arg"
            if $arg !~ m{\A [-]?\d+ \z}xms;
        my $sign = '+';
        if ($arg =~ s{\A [-]}{}xms) {
            $sign = '-';
        }
        return {
            sign   => $sign,
            digits => [ split //, $arg ],
        }
    }
    return $class->$orig(@args);
};

our ($zero, $one);
$zero = BigInteger->new('0');
$one  = BigInteger->new('1');

sub as_string {
    my ($self) = @_;
    return (($self->sign eq '-'? '-': '') . join '', @{$self->digits});
}

#
# module initialization
#
my (%addition_table, %subtraction_table);
for my $i (0 .. 9) {
    for my $j (0 .. 9) {
        $addition_table{$i.$j} = sprintf "%02d", $i + $j;
        my $diff = $i - $j;
        $subtraction_table{$i.$j} = $diff >= 0? '0' . $diff
                                   :            '1' . (10+$diff);
    }
}
# addition table has key = xy and value = cs
# x and y are digits 0 through 9
# s is x+y mod 10
# c is 1 if x+y >= 10
#
# 56 => 11 meaning 5+6 = 11 and that is 1 mod 10, with a carry
# 34 => 07 meaning 3+4 =  7 and no carry
#

# subtraction table has key = xy and value = bd
# x and y are digits 0 through 9
# d is x-y (mod 10) - so if x-y is -1 that yields 9
# b is 1 if x < y otherwise 0. i.e. 1 if there was
#                              a borrow from the next place
#
# 65 => 01 meaning 6-5 = 1 and no borrow was needed
# 34 => 19 meaning 13-4 = 9 and we needed to borrow


# add n zeros to the invocant and return a new BigInteger
# ??? how many zeros?  it's a Perl scalar
sub times_10 {
    my ($self, $n_0) = @_;
    my @digits = @{$self->digits};
    push @digits, ('0') x $n_0;
    return BigInteger->new({ sign => $self->sign, digits => \@digits });
}

sub times {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';

    if ($self == $zero || $b == $zero) {
        return $zero;
    }
    #
    # prepare the 10 multiples of abs $b
    my @multiple;
    $multiple[0] = $zero;
    my $c = $b->abs;
    for my $i (1 .. 9) {
        $multiple[$i] = $multiple[$i-1] + $c;
        # that was addition of BigIntegers
    }
    my @d2 = @{$self->digits};
    my $sum = $zero;
    my $n_0 = 0;
    while (@d2) {
        my $d = pop @d2;
        $sum += $multiple[$d]->times_10($n_0) if $d;
        # that was addition of BigIntegers
        ++$n_0;     # can we eliminate this addition???
                    # or make it a BigInteger?
                    # only matters if the multiplier
                    # has as many digits as the max int
                    # which is 2^64 - 1 = 18446744073709551615
                    # which is a LOT.  but we don't want
                    # limits, right?
    }
    if ($self->sign ne $b->sign) {
        return $sum->negate;
    }
    return $sum;
}

sub abs {
    my ($self) = @_;
    BigInteger->new({ sign => '+', digits => $self->digits });
}

sub plus {
    my ($self, $n) = @_;
    die "$n must be a BigInteger!" unless ref $n eq 'BigInteger';
    my @x = @{$self->digits};
    my @y = @{$n->digits};
    if ($self->sign ne $n->sign) {
        # subtraction
        if ($self->positive) {
            return $self->subtract($n->negate);
        }
        else {
            return $n->subtract($self->negate);
        }
    }
    my @result = ();
    my $carry = 0;
    LOOP:
    while (1) {
        my $d1 = pop @x;
        my $d2 = pop @y;
        if (! defined $d1 && ! defined $d2) {
            if ($carry) {
                unshift @result, '1';
            }
            last LOOP;
        }
        $d1 ||= '0';
        $d2 ||= '0';
        my $sum = $addition_table{$d1 . $d2};
        my $r = substr($sum, 1, 1);
        my $c = substr($sum, 0, 1);
        if ($carry) {
            $sum = $addition_table{$r . '1'};
            $r = substr($sum, 1, 1);
            # weird: it works whether I understand it or not :)
            $c = substr($sum, 0, 1) unless $c eq '1';
        }
        unshift @result, $r;
        $carry = $c;
    }
    return BigInteger->new({ sign => $self->sign, digits => \@result });
}

sub _digits_sum {
    my ($self, $b) = @_;
    my $save = $b->sign;
    $b->sign = $self->sign;
    my $c = $self + $b;
    $b->sign = $save;
    return @{$c->digits};
}

sub positive {
    my ($self) = @_;
    return $self->sign eq '+';
}
sub negative {
    my ($self) = @_;
    return $self->sign eq '-';
}

# if you wish, look up Knuth Vol 2 pg 265 for the algorithms
# for subtraction and division
# also see the source for bc and dc - at $HOME on akash2

# subtract $b from $self
#
sub subtract {
    my ($self, $b) = @_;
    croak "$b must be a BigInteger!" unless ref $b eq 'BigInteger';

    if ($self->positive && $b->negative) {
        # 9 - -8 = 17
        return $self->plus($b->negate);
    }
    if ($self->negative && $b->positive) {
        # -9 - 8 = -17
        return $self->negate->plus($b)->negate;
    }
    if ($self->negative && $b->negative) {
        # -9 - -8 = 8 - 9 = -1 
        return $b->negate->subtract($self->negate);
    }
    # so both self and b are positive
    my $cmp = $self->compare($b);
    if ($cmp == 1) {
        my @top = @{$self->{digits}};
        my @bot = @{$b->{digits}};
        my @result;
        my $borrow = 0;
        LOOP:
        while (1) {
            my $x = pop @top;
            if (! defined $x) {
                last LOOP;
            }
            if ($borrow) {
                my $diff = $subtraction_table{$x . '1'};
                $x = substr($diff, 1, 1);
                $borrow = substr($diff, 0, 1);
            }
            my $y = pop @bot;
            $y ||= '0';
            my $diff = $subtraction_table{$x.$y};
            my $result = substr($diff, 1, 1);
            $borrow = substr($diff, 0, 1) if ! $borrow; # ??
            unshift @result, $result;
        }
        # trim leading zeros
        while (@result && $result[0] eq '0') {
            shift @result;
        }
        if (! @result) {
            push @result, '0';
        }
        return BigInteger->new({ sign => '+', digits => \@result });
    }
    elsif ($cmp == -1) {
        return $b->subtract($self)->negate;
    }
    else {
        return $zero;
    }
}

sub equal {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    return  $self->compare($b) == 0;
}

sub not_equal {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    return  $self->compare($b) != 0;
}

sub greater_than {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    return  $self->compare($b) == 1;
}

sub less_than {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    return  $self->compare($b) == -1;
}

# $self <=> $b
# return -1, 0, or 1
sub compare {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    my $s_sign = $self->sign;
    my $b_sign = $b->sign;
    my $s_ndigits = @{$self->digits};
    my $b_ndigits = @{$b->digits};
    if ($s_sign eq '+' && $b_sign eq '-') {
        return 1;
    }
    if ($s_sign eq '-' && $b_sign eq '+') {
        return -1;
    }
    if ($s_sign eq '+' && $b_sign eq '+') {
        if ($s_ndigits > $b_ndigits) {
            return 1;
        }
        if ($s_ndigits < $b_ndigits) {
            return -1;
        }
        # same # of digits
        return "@{$self->digits}" cmp "@{$b->digits}";
    }
    # both signs are -
    if ($s_ndigits > $b_ndigits) {
        return -1;
    }
    if ($s_ndigits < $b_ndigits) {
        return 1;
    }
    return "@{$b->digits}" cmp "@{$self->digits}";
        # note that $b, $self are swapped
        # -34 <=> -45 yields 1 even though 34 < 45
}

sub negate {
    my ($self) = @_;
    return BigInteger->new( sign => $self->sign eq '+'? '-': '+',
                            digits => $self->digits );
}

#
# ignore the signs of $self and $b for now
#
# this was developed in a hacky way
# so not easy to follow.
# the tests prove it correct.
#
sub divide {
    my ($self, $b) = @_;
    die "$b must be a BigInteger!" unless ref $b eq 'BigInteger';
    die "cannot divide by zero!" if $b == $zero;

    #
    # see Euclidean.division.Wikipedia.pdf
    #
    # I think there are 8 cases:
    #
    # 1:   39   5   7   4   # 39 = 7*5 + 4
    # 2:   39  -5  -7   4
    # 3:  -39   5  -8   1   # -8 = -7-1, 1 = 5-4
    # 4:  -39  -5   8   1
    # 
    # 5:    5  39   0   5   # 5 = 39*0 + 5
    # 6:    5 -39   0   5   # 5 = -39*0 + 5
    # 7:   -5  39  -1  34   # -5 = 39*-1 + 34  (34 = 39-5)
    # 8:   -5 -39   1  34   # -5 = -39*1 + 34
    #
    my $negate_quo = 0;
    my $neg_pos = 0;
    my $neg_neg = 0;
    if ($self > $zero && $b < $zero) {
        $negate_quo = 1;
    }

    if ($b->abs > $self->abs) {
        if ($self->positive && $b->positive) {
            # 5:    5  39   0   5   # 5 = 39*0 + 5
            return ($zero, $self);
        }
        elsif ($self->positive && $b->negative) {
            # 6:    5 -39   0   5   # 5 = -39*0 + 5
            return $zero, $self;
        }
        elsif ($self->negative && $b->positive) {
            # 7:   -5  39  -1  34   # -5 = 39*-1 + 34  (34 = 39-5)
            return $one->negate, $self + $b;
        }
        else {
            # both negative
            # 8:   -5 -39   1  34   # -5 = -39*1 + 34
            return $one, $b->negate + $self;
        }
    }
    elsif ($self < $zero && $b > $zero) {
        $neg_pos = 1;
    }
    elsif ($self < $zero && $b < $zero) {
        $neg_neg = 1;
    }

    # first - create the 1-9 multiples of $b (or absolute value of $b).
    my @multiples;
    my $c = $b->abs;
    $multiples[1] = $c;
    for my $i (2 .. 10) {
        $multiples[$i] = $multiples[$i-1] + $c;
    }
    my @result;
    my @d = @{$self->digits};
    my @w;
    my $rem;
    INIT:
    while (@d) {
        push @w, shift @d;
        $rem = BigInteger->new(join '', @w);
        if ($c <= $rem) {
            last INIT;
        }
    }
    # so $c is <= $rem
    OUTER:
    while (1) {
        LOOP:
        for my $i (2 .. 10) {
            if ($multiples[$i] > $rem) {
                push @result, $i-1;
                $rem -= $multiples[$i-1];
                last LOOP;
            }
        }
        if (! @d) {
            last OUTER;
        }
        @w = @{$rem->digits};
        while (@d) {
            push @w, shift @d;
            $rem = BigInteger->new(join '', @w);
            if ($c <= $rem) {
                next OUTER;
            }
            push @result, 0;
        }
        if (! @d) {
            last OUTER;
        }
    }
    my $quo = BigInteger->new(join '', @result);

    #
    # result from the absolute values division
    # is $quo and $rem
    #
    if ($negate_quo) {
        # 2:   39  -5  -7   4
        return $quo->negate, $rem;
    }
    elsif ($neg_pos) {
        # 3:  -39   5  -8   1   # -8 = -7-1, 1 = 5-4
        return $quo->negate->subtract($one), $b - $rem;
    }
    if ($neg_neg) {
        # 4:  -39  -5   8   1
        return $quo->plus($one), ($b->negate - $rem)->abs;
    }
    # 1:   39   5   7   4   # 39 = 7*5 + 4
    return $quo, $rem;
}

1;
