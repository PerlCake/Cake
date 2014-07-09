package Cake::Helpers;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(
    params
);



sub params { shift->req->params(@_) }

1;
