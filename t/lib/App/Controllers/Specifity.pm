package App::Controllers::Specifity;
use Cake;

get ':[name1]/:[name2]' => sub {
	my $self = shift;
	my $c = shift;
	$c->body("from name1 name2");
};

get 'path/:[name]' => sub {
	my $self = shift;
	my $c = shift;
	$c->body("from path name");
};

get ':(.*?)/:(.*?)' => sub {
	my $self = shift;
	my $c = shift;
	my $splat = $c->splat;

	$c->body("from 2 regex " . $splat->[0] . ' ' .$splat->[1]);
};

1;
