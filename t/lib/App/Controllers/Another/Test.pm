package App::Controllers::Another::Test;
use Cake;
use Test::More;
use Data::Dumper;

get 'cool' => sub {
    my $self = shift;
    my $c = shift;

    my $arg1 = $c->param('arg1');
    $c->content_type('text/json');
    $c->body('From Controller cool ' . $arg1);
};

post 'post' => sub {
    my $self = shift;
    my $c = shift;

    my $arg1 = $c->param('arg1');
    my $arg2 = $c->param('arg2');

    # $c->content_type('text/json');
    $c->body($arg1 . ' ' . $arg2);
};


post qr{regex/(.*?)} => sub {
    my $self = shift;
    my $c = shift;

    my $splat = $c->splat;

    my $arg1 = $c->param('arg1');
    $c->body('Regex ' . $splat->[0] . ' ' . $arg1);
};

1;
