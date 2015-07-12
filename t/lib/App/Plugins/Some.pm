package App::Plugins::Some;
use Cake;

sub new {
	my $class= shift;
	my $options = shift;
	return bless {
        options => $options
    }, __PACKAGE__;
}

sub _set {
	my $self = shift;
	my $name = shift;
	my $value = shift;
	$self->{$name} = $value;
}

sub _get {
	my $self = shift;
	my $name = shift;
	return $self->{$name};
}

register_function 'someplugin' => sub {
    my $c = shift;
    return $c->plugin(__PACKAGE__);
};


get '/some/plugin' => sub {
	my $self = shift;
	my $c = shift;
	my $plugin = $c->someplugin();
	$plugin->_set("name", "value");
	my $value = $plugin->_get("name");
	$c->body('From plugin ' . $value . ' ' . $plugin->{options}->{option1});
};

1;
