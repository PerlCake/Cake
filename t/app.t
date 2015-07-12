BEGIN {
    $ENV{CAKE_CGI} = 0;
}

use Plack::Builder;
use Test::More;
use Data::Dumper;
use lib './t/lib';
use App;

use HTTP::Request::Common;
use Plack::Test;
use Plack::App::WrapCGI;
use HTTP::Cookies;
use HTTP::Headers;
use LWP::UserAgent;

if ($ENV{CAKE_CGI}){
    $app = Plack::App::WrapCGI->new(script => "./app.cgi")->to_app;
} else {
    $app = sub {
        my $env = shift;
        return App->bake($env);
    };
}

#simple hello
sub testSimple {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => "/test");
    my $res = $cb->($req);
    is $res->content, "Hello";
}

sub testRouteSpecifity {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => "/specifity/path/name");
    my $res = $cb->($req);
    is $res->content, "from path name";

    my $req = HTTP::Request->new(GET => "/specifity/name/name");
    my $res = $cb->($req);
    is $res->content, "from name1 name2";

    my $req = HTTP::Request->new(GET => "/specifity/name/name/anything");
    my $res = $cb->($req);
    is $res->content, "from 2 regex name name/anything";
}


sub testFromController {
    my $cb = shift;

    my $req = HTTP::Request->new(GET => "/test/controller");
    my $res = $cb->($req);
    is $res->content, "From Controller";
    is $res->content_type, "text/html";

    my $req = HTTP::Request->new(GET => "/test/settings");
    my $res = $cb->($req);
    is $res->content, "Secret CAKE";
    is $res->content_type, "text/html";

    my $req = HTTP::Request->new(GET => "/test/controller/hi");
    my $res = $cb->($req);
    is $res->content, "From Controller hi";
    is $res->content_type, "text/html";

    my $req = HTTP::Request->new(PUT => "/test/controller/hi");
    my $res = $cb->($req);
    is $res->content, "From PUT hi";
    is $res->content_type, "text/html";

    my $req = HTTP::Request->new(DELETE => "/test/controller/hi");
    my $res = $cb->($req);
    is $res->content, "From DELETE hi";
    is $res->content_type, "text/html";


    my $req = HTTP::Request->new(POST => "/test/any");
    my $res = $cb->($req);
    is $res->content, "From Any";
    is $res->content_type, "text/html";

    my $req = HTTP::Request->new(GET => "/test/any");
    my $res = $cb->($req);
    is $res->content, "From Any";
    is $res->content_type, "text/html";
    
    my $req = HTTP::Request->new(GET => "/another/test/cool?arg1=arg1");
    my $res = $cb->($req);
    is $res->content, "From Controller cool arg1";
    is $res->content_type, "text/json";

    my $req = HTTP::Request::Common::POST('/another/test/post',
        Content => {
            arg1 => 'Hi',
            arg2 => 'Bye'
        }
    );
    
    my $res = $cb->($req);
    is $res->content, "Hi Bye";
    is $res->content_type, "text/html";


    my $req = HTTP::Request::Common::POST('/another/test/regex/splat',
        Content => {
            arg1 => 'Hi',
        }
    );
    
    my $res = $cb->($req);
    is $res->content, "Regex splat Hi";
    is $res->content_type, "text/html";
}

sub testPlugins {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => "/some/plugin");
    my $res = $cb->($req);
    is $res->content, "From plugin value option1";
}

sub testGetCookies {
    my $cb = shift;

    my $req = HTTP::Request->new(
        GET => "http://localhost/getcookies",
        HTTP::Headers->new(Cookie => 'session=session1; sessionToken=session2')
    );

    my $res = $cb->($req);
    is $res->content, "from get cookies session1 session2";
}

sub testSetCookies {
    my $cb = shift;

    my $req = HTTP::Request->new(GET => "/setcookies");
    my $res = $cb->($req);

    my $cookie_jar = HTTP::Cookies->new;
    $cookie_jar->extract_cookies($res);

    my @cookies;
    $cookie_jar->scan( sub { @cookies = @_ });

    is $res->content, "from set cookies"; 
    is $cookies[1], 'CAKESESSION2';
    is $cookies[2], 'seesion2value';
    is $cookies[3], '/path';
    ok $cookies[8] && ($cookies[8] > (time() + (2 * 60 * 60 * 24)) - 5 ); #expires after 2 days
}

my @tests = (
    \&testSimple,
    \&testRouteSpecifity,
    \&testFromController,
    \&testPlugins,
    \&testSetCookies,
    \&testGetCookies
);

test_psgi $app, sub {
    my $cb  = shift;
    foreach my $test (@tests){
        $test->($cb);
    }
};

done_testing();

1;
