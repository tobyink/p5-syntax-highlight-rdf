use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $data = do { local $/ = <DATA> };
my $hl   = "Syntax::Highlight::RDF"->new;

for my $tok (@{ $hl->tokenize(\$data) })
{
	say $tok;
}

__DATA__
@prefix foo: <http://example.com/foo> .

<xyz> foo:bar 123 .

