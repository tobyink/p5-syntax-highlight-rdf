use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $hl = "Syntax::Highlight::RDF"->new;

$hl->tokenize(\*DATA);
$hl->_fixup("http://www.example.net/");

for my $tok (@{$hl->_tokens})
{
	print $tok->TO_HTML;
}

__DATA__
@base <http://www.example.org/> .
@prefix foo: <http://example.com/foo#> .
@prefix quux: <quux#>.

<xyz>
   foo:bar 123;
   foo:baz "Yeah\"Baby\"Yeah";
   foo:bum quux:quuux.

