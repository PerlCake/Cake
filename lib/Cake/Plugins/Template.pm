package Cake::Plugins::Template;
use strict;
use warnings;
use Data::Dumper;

my $self = {};
$self->{template_settings} = {
    evaluate => qr/<\%([\s\S]+?)\%>/,
    interpolate => qr/<\%=([\s\S]+?)\%>/
};

sub new {
    my $class = shift;
    my $settings = shift;
    bless $self, $class;
}

sub render {
    my $c = shift;
    my $temp = shift;
    my $settings = shift || {};
    $settings->{c} = $c;
    my $compile = $self->compile($temp);
    return $compile->($settings);
}

sub compile {
    my $self = shift;
    my $template = shift;

    my $evaluate    = $self->{template_settings}->{evaluate};
    my $interpolate = $self->{template_settings}->{interpolate};
    
    return sub {
        my ($args) = @_;
        
        my $code = q!sub {my ($args) = @_; my $_t = '';!;
        foreach my $arg (keys %$args) {
            $code .= "my \$$arg = \$args->{$arg};";
        }
        
        $template =~ s{$interpolate}{\}; \$_t .= $1; \$_t .= q\{}g;
        $template =~ s{$evaluate}{\}; $1; \$_t .= q\{}g;
        
        $code .= '$_t .= q{';
        $code .= $template;
        $code .= '};';
        $code .= 'return $_t};';
        
        my $sub = eval $code;
        if ($@){
            die $@;
        }
        return $sub->($args);
    };
}

sub include_template {
    my $c = shift;
    return shift;
}


1;
