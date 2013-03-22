use v5.10;
use strict;
use warnings;

use Syntax::Highlight::RDF;

my $hl = "Syntax::Highlight::RDF"->highlighter("JSON");

print $hl->highlight(\*DATA);

__DATA__
{
	"http://example.org/about": 
	{
		"http://purl.org/dc/elements/1.1/title":
		[
			{ "type": "literal" , "value": "Anna's Homepage" }
		]
	}
}
