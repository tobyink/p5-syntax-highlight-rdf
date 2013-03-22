use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $hl = "Syntax::Highlight::RDF"->new;

print $hl->highlightText(\*DATA, "http://www.example.net/");

__DATA__
@base <http://www.example.org/> .
@prefix foo: <http://example.com/foo#> .
@prefix quux: <quux#>.

<xyz>
   foo:bar 123;
   foo:baz "Yeah\"Baby\"Yeah";
   foo:bum quux:quuux.

