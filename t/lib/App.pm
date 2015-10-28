package App;
use Cake;
use Data::Dumper;

Settings {
    secret => 'CAKE',
    hashref => {
        apikey => '0123456789'
    }
};

Plugins [
    'App::Plugins::Some' => {
        option1 => 'option1',
        options2 => 'option2'
    }
];

loadControllers('Controllers');

##register digest function
register_function 'digest' => sub {
    my $c = shift;
};

register_function 'md5' => sub {
    my $c = shift;
};

register_function 'json_body' => sub {
    my $c = shift;
    my $body = shift;
    $c->content_type('application/json');
    if (ref $body){
        $c->body($c->to_json($body));
    } else {
        $c->body($body);
    }
};

get '/json' => sub {
    my $self = shift;
    my $c = shift;
    $c->cookies("hi", "there");
    $c->json_body([
        {
            name => 'wild',
            id => 1
        }
    ]);
};

get '/test' => sub {
    my $self = shift;
    my $c = shift;
    my $param = $c->param('test');
    # print STDERR Dumper $c;
    $c->body('Hello');
};

get '/some/model' => sub {
    my $self = shift;
    my $c = shift;
    my $model = $c->model('Test');
    my $message;

    if (!ref $model){ $message = "Error Blessing Model Instance"  }
    if ($model->{c} != $c){ $message = "Error Blessing Model Instance"  }

    $message = $model->returnSuccessTest();
    $c->body($message);
};

get '/getcookies' => sub {
    my $self = shift;
    my $c = shift;
    my $cookie = $c->cookies;
    $c->body('from get cookies ' . $cookie->{session} . ' ' . $cookie->{sessionToken});
};

get '/setcookies' => sub {
    my $self = shift;
    my $c = shift;

    $c->cookies("CAKESESSION", "Hello");
    $c->cookies("CAKESESSION2", {
        path => '/path',
        value => 'seesion2value',
        expires => '+2d'
    });

    $c->body('from set cookies');
};

1;
