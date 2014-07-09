package Cake::Routes;
use strict;
use warnings;
my $ROUTES = {};
my $CALLER = {};

sub set {
    my ($type, $path, $code) = @_;
    my @caller = caller(1);
    $ROUTES->{$path} = {};
    my $class = $caller[0];
    my $new;
    if (!$CALLER->{$class}) {
        if ($class->can('new')) {
            $new = $class->new();
        } else {
            $new = bless {}, $class;
        }
        $CALLER->{$class} = $new;
    }
    
    $ROUTES->{$path}->{$type} = {
        code => $code,
        class => $caller[0],
        file => $caller[1],
        line => $caller[2],
        path => $path,
        bless => $CALLER->{$class}
    };
}

sub match {
    my $c       = shift;
    my $request = $c->req;
    my $path    = $request->path;
    my $method  = $request->method;
    $c->{match} = undef; #undef previous match
    my $match;
    if ($ROUTES->{$path} && ($match = $ROUTES->{$path}->{$method}) ){
        $c->{match} = $match;
    }
    return;
}


sub inspect { $ROUTES }

1;
