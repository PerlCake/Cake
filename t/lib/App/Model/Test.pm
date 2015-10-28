package App::Model::Test;

sub new {
	my $class = shift;
	my $c = shift;

	return bless {
		c => $c
	}, $class;
}

sub returnSuccessTest {
	my $self = shift;
	return "Model Testing Success";
}

1;
