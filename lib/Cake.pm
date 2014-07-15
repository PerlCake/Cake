package Cake;
use strict;
use warnings;
use utf8;
use Carp;
use File::Find;
use File::Spec;
use Encode;
use Data::Dumper;
use base qw/Exporter/;
use FindBin qw($Bin);
our $VERSION = 0.001;

my $HTTPRequest  = eval q{
    use Plack::Request;
    'Plack::Request';
} || 'Cake::Request';

my $HTTPResponse = eval q{
    use Plack::Response;
    'Plack::Response';
} || 'Cake::Response';

my $isCGI = $ENV{GATEWAY_INTERFACE} && $ENV{GATEWAY_INTERFACE} eq 'CGI/1.1';

if ($isCGI) {
    $HTTPResponse = 'Cake::Response';
    $HTTPRequest  = 'Cake::Request';
}

our @EXPORT = qw(loadControllers plugins bake get post any model models around_match);
my $cake = bless {}, __PACKAGE__;
sub new { return $cake }
sub log {}

#==============================================================================
# import
#==============================================================================
sub import {
    my ($class, @options) = @_;
    ###import these to app by default
    strict->import;
    warnings->import;
    utf8->import;
    if (!$cake->{app}){
        my ($package,$script) = caller;
        $cake->{app} = {};
        $cake->{app}->{'basename'} = $script;
        ( $cake->{app}->{'dir'} = $INC{$package} || $Bin) =~ s/\.pm//;
        push @INC, $cake->{app}->{'dir'};
        $cake->{app} = bless $cake->{app}, $package;
    }
    $class->export_to_level(1, $class, @EXPORT);
}

#==============================================================================
# around_match
#==============================================================================
my $next_around_match = 0;
my @around_match = (sub{
    shift;
    my $c = shift;
    $c->match();
});

sub _run_around_match {
    my $self = shift;
    my $next = $around_match[$next_around_match];
    $next_around_match++;
    $next->('_run_around_match',$self,@_);
}

sub around_match {
    my $sub = shift;
    croak "around_match accepts a code ref only" if ref $sub ne 'CODE';
    unshift @around_match, $sub;
}

sub _reset_around_match { $next_around_match = 0 }

#==============================================================================
# plugins loader
#==============================================================================
my $plugins = {};
sub plugins {
    my @plugins = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    while (@plugins){
        my $plugin = shift @plugins;
        my $settings = {};
        my $blessed;
        if (ref $plugin){
            die 'wrong plugin decleration';
        } elsif (ref $plugins[0]){
            $settings = shift @plugins;
        }
        
        eval "use $plugin; 1;" or croak $@;
        if ( $plugin->can('new') ){
            $plugin->new($settings);
        }
        unshift @Cake::ISA,$plugin;
        $plugins->{$plugin} = $settings;
    }
}

sub config { $plugins }

#==============================================================================
# models loader
#==============================================================================
my $models = {};
sub models {
    my @models = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    while (@models){
        my $model = shift @models;
        my $settings = {};
        my $blessed;
        if (ref $model){
            croak 'wrong model decleration';
        } elsif (ref $models[0]){
            $settings = shift @models;
        }
        
        eval "use $model; 1;" or croak $@;
        if ( $model->can('new') ){
            $blessed = $model->new($settings);
        } else {
            $blessed = bless $settings, $model;
        }
        $models->{$model} = $blessed;
    }
}

sub model {
    my $model = shift;
    $model = $cake->{app}->{'basename'} . '::Model::' . $model;
    my $settings = $_[0] || {};
    if ( !$models->{$model} ){
        #didn't register it yet, go ahead
        models [$model => $settings];
    } else {
        if ($_[0] && $model->can('new')){
            return $model->new($settings);
        }
    }
    return $models->{$model};
}

#==============================================================================
# load controllers
#==============================================================================
our $controllers_dir;
sub loadControllers {
    my $dir = shift || 'Controllers';
    $controllers_dir = $dir;
    $dir = File::Spec->rel2abs( $dir, ref $cake->app ) ;
    warn "loading Controllers From " . $dir;
    if (!-d $dir){
        warn "Can't find " . $dir . "\nContollers will not be loaded";
        return;
    }
    
    find(sub {
        if ($_ =~ m/\.pm$/){
            my $file = $File::Find::name;
            eval "require '$file'";
            if ($@) {
                die("can't load controller $file");
            }
        }
    }, $dir);
}

#== routes ====================================================================
sub any    { Cake::Routes::set('ANY'   , @_) }
sub get    { Cake::Routes::set('GET'   , @_) }
sub post   { Cake::Routes::set('POST'  , @_) }
sub head   { Cake::Routes::set('HEAD'  , @_) }
sub put    { Cake::Routes::set('PUT'   , @_) }
sub delete { Cake::Routes::set('DELETE', @_) }
sub match  { Cake::Routes::match(@_)         }

#== short cuts ================================================================
sub app    { shift->{app}      }
sub req    { shift->{request}  }
sub res    { shift->{response} }
sub env    { shift->{request}->env  }

#==============================================================================
# bake the cake
#==============================================================================
sub bake {
    my $class = shift;
    my $env = shift || \%ENV;
    $cake->{request}  =  $HTTPRequest->new($env);
    $cake->{response} =  $HTTPResponse->new();
    _reset_around_match();
    return $cake->_run();
}

#==============================================================================
# bake the cake
#==============================================================================
sub _run {
    my $self = shift;
    _run_around_match($self);
    if (my $match = $self->{match}){
        $match->{code}->($match->{bless},$self);
    } else {
        #no match
    }
    _reset_around_match();
    return $self->finalize();
}

sub finalize {
    my $c = shift;
    if (!$c->res->status) {
        $c->res->status(200);
    }
    return $c->res->finalize();
}

#==============================================================================
# Helpers
#==============================================================================
sub to_json {
    my $self = shift;
    my $data = shift;
    return Cake::JSON::convert_to_json($data);
}

sub splat {
    my $c = shift;
    if (@_ > 0) {
        return $c->{match}->{splat}->[$_[0]];
    }
    return $c->{match}->{splat};
}

sub capture {
    my $c = shift;
    if (@_ > 0) {
        return $c->{match}->{capture}->{$_[0]};
    }
    return $c->{match}->{capture};
}

sub to_perl {
    my $self = shift;
    my $json_string = shift;
    return Cake::JSON::convert_to_perl($json_string);
}

#== Response methods ==========================================================
sub redirect       {  shift->res->redirect(@_)       }
sub body           {  shift->res->body(@_)           }
sub header         {  shift->res->header(@_)         }
sub headers        {  shift->res->headers(@_)        }
sub status         {  shift->res->status(@_)         }
sub content_type   {  shift->res->content_type(@_)   }
sub content_length {  shift->res->content_length(@_) }

my %epoch = (s => 1, m => 60, h => 60 * 60,
             d => 60 * 60 * 24, M => 60 * 60 * 24 * 30,
             y => 60 * 60 * 24 * 30 * 12);

sub cookies {
    my $self = shift;
    my $name = shift;
    if (@_){
        my $value = shift;
        #convert strings to epoch time as Plack::Response
        #doesn't support string format in cookies
        if ($HTTPResponse eq 'Plack::Response' && ref $value eq 'HASH') {
            if ($value->{expires}) {
                my $expire = $value->{expires};
                if ($expire =~ s/^\+//) {
                    my ($t,$e) = ($expire =~ /(\d+)(\w)/);
                    my $epoch = $epoch{$e} || (60 * 60 * 24);
                    $value->{expires} = time + $t * $epoch;
                }
            }
        }
        $self->res->cookies->{$name} = $value;
        return;
    } elsif ($name){
        my $cookies = $self->req->cookies() || {};
        return $cookies->{$name};
    }
    return return $self->req->cookies();
}

#== Request methods ===========================================================
sub path    {  shift->req->path(@_)    }
sub method  {  shift->req->method()    }
sub param   {  shift->req->param(@_)   }
sub params   {  shift->req->params     }

#== uri methods ===============================================================
sub uri_encode {
    return '' if !defined $_[0];
    $_[0] =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
    return $_[0];
}

sub uri_decode {
    $_[0] =~ tr/+/ /;
    $_[0] =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    return $_[0];
}

#==============================================================================
# uri_for
#==============================================================================
sub uri_for {
    my $self = shift;
    return $self->_get_full_url(@_);
}

#==============================================================================
# return current url with path & parameters
# we can add new params to the requested URL
#==============================================================================
sub uri_with {
    my $self = shift;
    my $params = $self->params;
    return $self->_get_full_url(@_,$params);
}

#=============================================================================
# get current full url
#=============================================================================
sub is_secure {
    return $_[0]->env->{'SSL_PROTOCOL'} ? 1 : 0;
}

sub uri_base {
    my $self = shift;
    my $base = 'http';
    $base .='s' if $self->is_secure();
    $base .= '://'.$self->env->{HTTP_HOST};
    return $base;
}

sub _get_full_url {
    my $self = shift;
    my @params;
    my $url = $self->uri_base;
    my $top_level = 0;
    my $script = $self->env->{SCRIPT_NAME};
    if ($self->env->{REQUEST_URI} =~ m/^$script/){
        $url .= $script;
    }
    
    foreach my $uri (@_){
        if (!ref $uri) {
            if ($uri =~ /^http/) {
                die "http $uri must be first argument" if $top_level;
                $url = $uri;
            } else {
                if ($top_level == 0 && $uri !~ /^\//) {
                    $url .= $self->path . '/';
                } elsif ($top_level && $uri !~ /^\//){
                    $url .= '/';
                }
                $url .= $uri;
            }
            $top_level = 1;
        } elsif (ref $uri eq 'HASH'){
            while (my ($key,$value) = each(%{$uri})) {
                push(@params,$key.'='.uri_encode($value));
            }
        }
    }
    
    if (@params) {
        my $params = join('&',@params);
        $url .= '?'.$params;
    }
    return $url;
}

#==============================================================================
# Request Package
#==============================================================================
package Cake::Request; {
    use strict;
    use warnings;
    use CGI;
    use CGI::Cookie;
    use Data::Dumper;
    sub new {
        my($class, $env) = @_;
        Carp::croak(q{$env is required})
        unless defined $env && ref($env) eq 'HASH';
        %ENV = %{$env};
        my $cgi;
        if ($env->{'PSGI.INPUT'}) {
            $cgi = CGI->new($env->{'PSGI.INPUT'});
        } else {
            $cgi = CGI->new;
        }
        
        bless {
            env => $env,
            cgi => $cgi
        }, $class;
    }
    
    sub env {$_[0]->{env}}
    sub cgi {$_[0]->{cgi}}
    
    sub address     { $_[0]->env->{REMOTE_ADDR} }
    sub remote_host { $_[0]->env->{REMOTE_HOST} }
    sub protocol    { $_[0]->env->{SERVER_PROTOCOL} }
    sub method      { $_[0]->env->{REQUEST_METHOD} }
    sub port        { $_[0]->env->{SERVER_PORT} }
    sub user        { $_[0]->env->{REMOTE_USER} }
    sub request_uri { $_[0]->env->{REQUEST_URI} }
    sub path_info   { $_[0]->env->{PATH_INFO} }
    sub path        { $_[0]->env->{PATH_INFO} || '/' }
    sub script_name { $_[0]->env->{SCRIPT_NAME} }
    sub scheme      { $_[0]->env->{'psgi.url_scheme'} }
    sub secure      { $_[0]->scheme eq 'https' }
    
    sub content_length   { $_[0]->env->{CONTENT_LENGTH} }
    sub content_type     { $_[0]->env->{CONTENT_TYPE} }
    
    sub cookies {
        my $self = shift;
        my $name = shift;
        my %cookies;
        if (!$self->{cookies}) {
            %cookies = CGI::Cookie->parse($self->env->{HTTP_COOKIE});
            for (keys %cookies){
                $self->{cookies}->{$_} = $cookies{$_}->value;
            }
        }
        return $self->{cookies};
    }
    
    sub param { shift->cgi->param(@_) }
    sub params { shift->cgi->Vars }
}

#==============================================================================
# Response Package
#==============================================================================
package Cake::Response; {
    use strict;
    use warnings;
    use CGI (); use CGI::Cookie;
    sub new {
        my ($class,$options) = @_;
        return bless {
            content_type => 'text/html',
            status_code => 200,
            cookies => {},
            headers => [],
            cgi => CGI->new
        }, $class;
    }
    
    sub body {
        my $self = shift;
        my $body = shift;
        my $content = '';
        if (ref $body eq 'ARRAY') {
            
        } else {
            $content = $body;
        }
        $self->{body} = $content;
    }
    
    sub cookies {
        my $self = shift;
        my $name = shift;
        return $self->{cookies};
    }
    
    sub redirect {
        my $self = shift;
        $self->{redirect} = \@_;
    }
    
    sub content_type {
        my $self = shift;
        $self->{content_type} = shift;
    }
    
    sub headers {
        my $self = shift;
    }
    
    sub header {
        my $self = shift;
        die "usage : header( 'Name' => 'content' )" if @_ != 2;
        push @{$self->{headers}},@_;
    }
    
    sub status {
        my $self = shift;
        $self->{status_code} = shift;
    }
    
    sub finalize {
        my $self = shift;
        ##finalize cookies
        my $cookies = $self->_finalize_cookies;
        my $content_length = $self->_get_content_length;
        print $self->{cgi}->header(
            -Content_length => $content_length,
            -type => $self->{content_type},
            -status => $self->{status_code},
            -cookie => $cookies,
            @{$self->{headers}}
        );
        print $self->{body};
    }
    
    sub _get_content_length {
        my $self = shift;
        if (defined $self->{content_length}) {
            return $self->{content_length};
        }
        return length $self->{body};
    }
    
    sub _finalize_cookies {
        my $self = shift;
        my $cookies = $self->{cookies};
        my @cookies;
        for (keys %{$cookies}){
            my $key = $_;
            my $value = $cookies->{$key};
            my %cookie = ( -name => $key ); 
            if (ref $value eq 'HASH') {
                for (keys %{$value}){
                    $cookie{$_} = $value->{$_};
                }
            } else {
                $cookie{-value} = $value;
            }
            push @cookies, $self->{cgi}->cookie(%cookie);
        }
        return \@cookies;
    }
    
    sub content_length {
        my $self = shift;
        $self->{content_length} = shift;
    }
}

#==============================================================================
# Routes Package
#==============================================================================
package Cake::Routes; {
    use strict;
    use Data::Dumper;
    use warnings;
    my $ROUTES = {};
    my $CALLER = {};
    my $FASTMATCH = {};
    my @SORTED;
    my %r = ( num => '(\d+)' );
    sub set {
        my ($type, $path, $code) = @_;
        my @caller = caller(1);
        my $class = $caller[0];
        my @paths = split '/', $path;
        my (@newPath,@capture,$new);
        if ($paths[0] ne '' && ref $path ne 'Regexp') {
            my $class_path = $class;
            my $c_dir = lc($Cake::controllers_dir) . "::";
            $class_path =~ s/(.*)\Q$c_dir//ig;
            $class_path =~ s/::/\//g;
            unshift @paths, ('', lc $class_path);
        }
        
        if (ref $path eq 'Regexp' || $path =~ /:/g) {
            my $specifity = 0;
            if (ref $path eq 'Regexp') {
                push @newPath, $path; goto SKIP;
            }
            
            foreach my $p (@paths){
                if ( $p =~ /^:{(.*?)}/) {
                    $p = $r{$1}; push @capture, '__SPLAT__';
                } elsif ($p =~ m/^:\[(.*?)\]/){
                    push @capture, $1;
                    $p = '([^\/\.\?]+)';
                } elsif ($p =~ m/^:(\(.*?\))/){
                    $p = $1; push @capture, '__SPLAT__';
                } else { $specifity++ } #direct paths with higher order
                push @newPath, $p;
            }
            
            SKIP :{1};
            my $newPath = join '/', @newPath;
            my $len = scalar @paths;
            $FASTMATCH->{$len} ||= {max => 0};
            $FASTMATCH->{$len}->{$specifity} ||= [];
            if ($specifity > $FASTMATCH->{$len}->{max}) {
                $FASTMATCH->{$len}->{max} = $specifity;
            }
            
            ##create a unique id for this regex path
            $path = ":MATCH:$len:" . "$specifity:" .
                @{$FASTMATCH->{$len}->{$specifity}};
            
            push @{$FASTMATCH->{$len}->{$specifity}},
                [qr{$newPath}, \@capture, $path];
            
        } else {
            $path = join '/', @paths;
        }
        
        $ROUTES->{$path} = {};
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
            bless => $CALLER->{$class},
            splat => [],
            capture => {}
        };
    }
    
    ## 1 - direct matches first
    ## 2- mix of regex and direct match
    
    ## ex: /path/hi/:name & /path/:name/:name2
    ## when matching /path/hi/mamod should match
    ## /path/hi/:name
    
    ##3- specifity /path/:name/:name2 & /path/:(.*?)
    ## /path/mamod/mehyar should match /path/:name/:name2
    
    #FASTMATCH = {
    #    'number of paths' => { 'specifity' => [route1,route2,...] } }
    
    sub match {
        my $c       = shift;
        my $request = $c->req;
        my $path    = $request->path;
        my $method  = $request->method;
        $c->{match} = undef; #undef previous match
        my $match;
        ##direct match / fast case
        if ($ROUTES->{$path} && ($match = $ROUTES->{$path}->{$method}) ){
            $c->{match} = $match;
        } else {
            #sort only once
            if (!@SORTED) { @SORTED = reverse (sort keys %$FASTMATCH) }
            ##start searching from the largest path regex /(.*?)/(\d+)../..
            #down to the least /(.*?) = wild card
            foreach my $i (@SORTED){
                my $routes = $FASTMATCH->{$i} || next;
                ##now for specifity, meaning start to match path with
                ##less regex first, /test/foo/(.*?) should match
                ##before /(.*?)/(.*?) if path is /test/foo/something
                for (my $x = $routes->{max}; $x >= 0; $x--){
                    my $route = $routes->{$x} || next;
                    foreach my $regex (@{$route}){
                        my $rex = $regex->[0];
                        my @captures;
                        next unless (@captures = ($path =~ m/$rex$/));
                        my $path  = $regex->[2];
                        if ($ROUTES->{$path}
                                && ($match = $ROUTES->{$path}->{$method}) ){
                            
                            my $splat = $regex->[1];
                            _match_regex($c,$match, \@captures, $splat);
                            return;
                        }
                    }
                }
            };
        }
        return;
    }
    
    sub _match_regex {
        my ($c, $match, $captures, $splat) = @_;
        my %captured;
        my @splats;
        for (0 .. @{$splat}-1){
            if ($splat->[$_] ne '__SPLAT__') {
                $captured{$splat->[$_]} = $captures->[$_];
            } else {
                push @splats,  $captures->[$_];
            }
        }
        
        if (!@$splat) {
            @splats = @$captures;
        }
        
        $match->{capture}  = \%captured;
        $match->{splat}    = \@splats;
        $c->{match}        = $match;
        return;
    }
    
    sub inspect { $ROUTES }
}

#==============================================================================
# JSON serilization
# this is a very slow hack, we will try to use JSON::XS & JSON if available
#==============================================================================
package Cake::JSON; {
    use strict;
    use warnings;
    our ($json_xs,$json_pp);
    $json_xs = eval "use JSON::XS; 1;";
    if (!$json_xs) {
        $json_pp = eval "use JSON; 1;";
    }
    
    sub convert_to_json {
        my $perl_object = shift;
        if ($json_xs) {
            return JSON::XS::encode_json($perl_object);
        } elsif ($json_pp){
            return JSON::encode_json($perl_object);
        }
        my $trim = 1;
        my $dumper = Data::Dumper->new([ _stringify($perl_object,'encode') ]);
        $dumper->Purity(1)->Terse(1)->Indent(1)->Deparse(1)->Pair(' : ');
        my $json = $dumper->Dump;
        $json =~ s/(?:'((.*?)[^\\'])?')/$1 ? '"'.$1.'"' : '""'/ge;
        $json =~ s/\\'/'/g;
        $json =~ s/\\\\/\\/g;
        $json =~ s/(\\x\{(.*?)\})/chr(hex($2))/ge;
        if ($trim){
            $json =~ s/\n//g;
            $json =~ s/\s+//g;
        }
        return $json;
    }
    
    sub convert_to_perl {
        my $data = shift;
        if ($json_xs) {
            return JSON::XS::decode_json($data);
        } elsif ($json_pp){
            return JSON::decode_json($data);
        }
        #remove comments
        $data =~ s/\n+\s+/\n/g;
        $data =~ s/[\n\s+]\/\*.*?\*\/|[\n\s+]\/\/.*?\n/\n/gs;
        if ($data){
            $data =~ s/(["'])(?:\s?)+:/$1=>/g;
            $data =~ s/[^\\]([\@\$].*?\s*)/ \\$1/g;
        }
        
        my $str = eval "$data";
        die "invalid json" if $@;
        return $str;
        #return _stringify($data);
    }
    
    sub _stringify {
        my $hash = shift;
        my $type = shift || 'decode';
        my $newhash = {};
        my $array = 0;
        my $loop;
        
        my $action = {
            decode => \&_decode_string,
            encode => \&_encode_string,
        };
        
        if (!ref $hash){
            return $action->{$type}($hash);
        } elsif (ref $hash eq 'ARRAY') {
            $loop->{array} = $hash;
            $array = 1;
        } else {
            $loop = $hash
        }
        
        while (my ($key,$value) = each (%{$loop}) ) {
            if (ref $value eq 'HASH'){
                $newhash->{$key} = _stringify($value,$type);
            } elsif (ref $value eq 'ARRAY'){
                push @{$newhash->{$key}}, map { _stringify($_,$type) } @{$value};
            } else {
                $newhash->{$key} = $action->{$type}->($value);
            }
        }
        return !$array ? $newhash : $newhash->{array};
    }
    
    sub _encode_string {
        my $str = shift;
        return 0 if $str && $str =~ /^\d$/ && $str == 0;
        return '' if !$str;
        my @search = ('\\', "\n", "\t", "\r", "\b", "\f", '"');
        my @replace = ('\\\\', '\\n', '\\t', '\\r', '\\b', '\\f', '\"');
        map { $str =~ s/\Q$search[$_]/$replace[$_]/g } (0..$#search);
        return $str;
    }
    
    sub _decode_string {
        my $str = shift;
        return '' if !$str;
        my @search = ('\\\\', '\\n', '\\t', '\\r', '\\b', '\\f', '\"');
        my @replace = ('\\', "\n", "\t", "\r", "\b", "\f", '"');
        map { $str =~ s/\Q$search[$_]/$replace[$_]/ } (0..$#search);
        return $str;
    }
}

1;

__END__

=head1 NAME

Cake - a piece of cake micro framework

=head1 DESCRIPTION

PerlCake is a minimal/Micro web framework that runs under both environments
PSGI & CGI
