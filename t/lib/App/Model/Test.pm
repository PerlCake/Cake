package App::Model::Test;

sub init {
	my $class = shift;
	my $c = shift;

	return bless {
		c => $c,
		msg => 'Model Testing'
	}, $class;
}

sub returnSuccessTest {
	my $self = shift;
	return $self->{msg} . " Success";
}

1;
