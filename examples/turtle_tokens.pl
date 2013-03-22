use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $data = do { local $/ = <DATA> };
my $hl   = "Syntax::Highlight::RDF"->highlighter("Turtle");

$hl->tokenize(\$data);
$hl->_fixup("http://www.example.net/");

for my $tok (@{$hl->_tokens})
{
	say $tok->tok;
}

__DATA__
@base <http://www.example.org/> .
@prefix foo: <http://example.com/foo#> .
@prefix quux: <quux#>.

<xyz>
   foo:bar 123;
   foo:baz "Yeah\"Baby\"Yeah";
   foo:bum quux:quuux.

