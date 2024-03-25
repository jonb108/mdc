package Num;
use Moo;
use Carp qw/
    croak
/;

# an array of digits 0-9
# with ones, tens, hundreds, etc in that order
has 'digits' => (
    is => 'ro',
    isa => sub {
        my $aref = shift;
        croak unless ref $aref eq 'ARRAY';
        for my $e (@$aref) {
            croak unless $e =~ m{\A \d \z}xms;
        }
    },
    required => 1,
);
has 'decimals' => (
    is => 'ro',
    isa => sub {
        my $aref = shift;
        croak unless ref $aref eq 'ARRAY';
        for my $e (@$aref) {
            croak unless $e =~ m{\A \d \z}xms;
        }
    },
    required => 0,
);
# either 1 or 0 meaning negative or positive
has 'sign' => (
    is => 'ro',
    required => 1,
);

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    if (@args == 0 || ! defined $args[0]) {
        croak "missing numeric argument";
    }
    if (@args == 1 && !ref $args[0]) {
        my $arg = $args[0];
        my $sign = $arg =~ s{\A [_]}{}xms? 1: 0;
        $arg =~ s{\A 0*(?=\d)}{}xms;  # trim superfluous leading zeros
        my ($num, $dec) = split /[.]/, $arg;
        $num ||= '';
        $dec ||= '';
        croak "illegal number: $arg"
            if $num && $num !~ m{\A \d+ \z}xms
               ||
               $dec && $dec !~ m{\A \d+ \z}xms;
        return {
            digits   => [ reverse split //, $num ],
            decimals => [ split //, $dec ],
            sign     => $sign,
        }
    }
    return $class->$orig(@args);
};

sub ndigits {
    my ($self) = @_;
    return scalar(@{$self->digits});
}

sub add {
    my ($a, $b) = @_;
    if ($a->sign && $b->sign) {
        return $a->negate->add($b->negate)->negate;
    }
    if ($a->sign and !$b->sign) {
        return $b->minus($a->negate);
    }
    if (!$a->sign and $b->sign) {
        return $a->minus($b->negate);
    }

    # first add the decimal digits
    # and see if we have a carry into the one's place
    my @x_digs = @{$a->decimals};
    my @y_digs = @{$b->decimals};
    if (@x_digs > @y_digs) {
        push @y_digs, (0) x (@x_digs - @y_digs);
    }
    else {
        push @x_digs, (0) x (@y_digs - @x_digs);
    }
    @x_digs = reverse @x_digs;
    @y_digs = reverse @y_digs;
    my @d_sum;
    my $d_carry = 0;
    for my $i (0 .. $#x_digs) {
        my $d = $x_digs[$i] + $y_digs[$i] + $d_carry;
        if ($d < 10) {
            push @d_sum, $d;
            $d_carry = 0;
        }
        else {
            push @d_sum, $d % 10;
            $d_carry = 1;
        }
    }

    my @a_digs = @{$a->digits};
    my @b_digs = @{$b->digits};
    my @sum;
    my $carry = $d_carry;
    for my $i (0 .. $#a_digs) {
        my $d = $a_digs[$i] + ($b_digs[$i] || 0) + $carry;
        if ($d < 10) {
            push @sum, $d;
            $carry = 0;
        }
        else {
            push @sum, $d % 10;
            $carry = 1;
        }
    }
    if (@b_digs > @a_digs) {
        for my $i ($#a_digs+1 .. $#b_digs) {
            my $d = $b_digs[$i] + $carry;
            if ($d < 10) {
                push @sum, $d;
                $carry = 0;
            }
            else {
                push @sum, $d % 10;
                $carry = 1;
            }
        }
    }
    if ($carry) {
        push @sum, 1;
    }
    return Num->new({
        digits   => \@sum,
        decimals => [ reverse @d_sum ],
        sign     => 0,
    });
}

sub negate {
    my ($a) = @_;
    my $sign = $a->sign? '': '_';
    return Num->new({
        digits   => $a->{digits},
        decimals => $a->{decimals},
        sign     => $a->{sign}? 0: 1,
    });
    return Num->new($sign . reverse @{$a->digits});
}

# a minus b
#  45
#-196
#  09
sub minus {
    my ($a, $b) = @_;
    if ($a->sign && $b->sign) {
        # -4 - -5
        return $b->negate->minus($a->negate);
    }
    if (!$a->sign && $b->sign) {
        # 4 - -5
        return $a->add($b->negate);
    }
    if ($a->sign && !$b->sign) {
        # -4 - 5
        return $a->negate->add($b)->negate;
    }
    # both are positive
    my $cmp = $a->compare($b);
    if ($cmp == -1) {
        # a is strictly less than b
        # 4 - 5
        return $b->minus($a)->negate;
    }
    if ($cmp == 0) {
        return Num->new(0);
    }
    # two positive, a > b
    # 54 - 2
    # 52 - 4
    my @result;
    my @a_digs = @{$a->digits};
    my @b_digs = @{$b->digits};
    for my $i (0 .. $#a_digs) {
        my $dif = $a_digs[$i] - ($b_digs[$i] || 0);
        if ($dif >= 0) {
            push @result, $dif;
        }
        else {
            # borrow one from the next place
            push @result, 10 + $dif;
            --$a_digs[$i+1];
        }
    } 
    # ???
    return Num->new({
        decimals => 0,
        digits => \@result,
        sign   => 0,
    });
}

# a  > b =>  1
# a  < b => -1
# a == b =>  0
sub compare {
    my ($a, $b) = @_;
    if (!$a->sign && $b->sign) {
        # 4 -9
        return 1;
    }
    if ($a->sign && !$b->sign) {
        # -4 9
        return -1;
    }
    if ($a->sign && $b->sign) {
        # -4 -9
        return $b->negate->compare($a->negate);
    }
    my $na = $a->ndigits;
    my $nb = $b->ndigits;
    if ($na > $nb) {
        # 99 4
        return 1;
    }
    if ($na < $nb) {
        # 4 99
        return -1;
    }
    # 49 48
    my @a_digs = @{$a->digits};
    my @b_digs = @{$b->digits};
    while (@a_digs) {
        my $ad = pop @a_digs;
        my $bd = pop @b_digs;
        if ($ad > $bd) {
            return 1;
        }
        if ($ad < $bd) {
            return -1;
        }
    }
    return 0;   # equal!
}

sub times_10 {
    my ($a, $n) = @_;
    unshift @{$a->{digits}}, (0) x $n;
    return $a;
}

#
# Num $a multiplied by digit $n
#
sub _times_one {
    my ($a, $n) = @_;
    my $carry = 0;
    my @product;
    for my $d (@{$a->digits}) {
        my $p = $d * $n + $carry;
        if ($p < 10) {
            push @product, $p;
            $carry = 0;
        }
        else {
            push @product, $p % 10;
            $carry = int($p / 10);
        }
    }
    if ($carry) {
        push @product, $carry;
    }
    return Num->new(join '', reverse @product);
}

sub times {
    my ($a, $b) = @_;
    if ($a->sign && $b->sign) {
        return $a->negate->times($b->negate);
    }
    if (!$a->sign && $b->sign) {
        return $a->times($b->negate)->negate;
    }
    if ($a->sign && !$b->sign) {
        return $a->negate->times($b)->negate;
    }
    # two positives
    my $product = Num->new(0);
    my $n = 0;
    for my $d (@{$b->digits}) {
        $product = $product->add($a->_times_one($d)->times_10($n));
        ++$n;
    }
    return $product;
}

sub str {
    my ($self) = @_;
    return (($self->sign? '-': '')
         . join('', reverse @{$self->digits}));
}

sub show {
    my ($self) = @_;
    if ($self->sign) {
        print "-";
    }
    print join('', reverse @{$self->digits});
    if ($self->decimals && @{$self->decimals}) {
        print '.' . join('', @{$self->decimals});
    }
    print "\n";
}

1;
