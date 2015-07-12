package App::Controllers::Test;
use Cake;
use Test::More;
use Data::Dumper;

get 'controller' => sub {
    my $self = shift;
    my $c = shift;
    $c->body('From Controller');
};

del 'controller/:[name]' => sub {
    my $self = shift;
    my $c = shift;
    $c->body('From DELETE ' . $c->capture->{name} );
};

put 'controller/:[name]' => sub {
    my $self = shift;
    my $c = shift;
    $c->body('From PUT ' . $c->capture->{name} );
};

get 'controller/:[name]' => sub {
    my $self = shift;
    my $c = shift;
    $c->body('From Controller ' . $c->capture->{name} );
};


get 'settings' => sub {
    my $self = shift;
    my $c = shift;
    my $secret = $c->settings->{secret};
    $c->body('Secret ' . $secret );
};

any ['post', 'get'] => 'any' => sub {
    my $self = shift;
    my $c = shift;
    $c->body('From Any');
};

1;
