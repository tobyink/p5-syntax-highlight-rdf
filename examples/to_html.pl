use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $hl = "Syntax::Highlight::RDF"->new;

for my $tok (@{ $hl->tokenize(\*DATA) })
{
	print $tok->TO_HTML;
}

__DATA__
@prefix foo: <http://example.com/foo> .

<xyz>
   foo:bar 123;
   foo:baz "Yeah\"Baby\"Yeah".

