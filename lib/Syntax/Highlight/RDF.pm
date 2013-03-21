package Syntax::Highlight::RDF;

use 5.010001;
use strict;
use warnings;

BEGIN {
	$Syntax::Highlight::RDF::AUTHORITY = 'cpan:TOBYINK';
	$Syntax::Highlight::RDF::VERSION   = '0.001';
}

use MooX::Struct -retain,
	Token                     => [qw($spelling)],
	PrefixDefinition          => [-extends => [qw<Token>], qw($expansion)],
	PrefixDefinition_Start    => [-extends => [qw<PrefixDefinition>]],
	PrefixDefinition_End      => [-extends => [qw<PrefixDefinition>]],
	Comment                   => [-extends => [qw<Token>]],
	Brace                     => [-extends => [qw<Token>]],
	Bracket                   => [-extends => [qw<Token>]],
	Parenthesis               => [-extends => [qw<Token>]],
	Datatype                  => [-extends => [qw<Token>]],
	AtRule                    => [-extends => [qw<Token>]],
	Shorthand                 => [-extends => [qw<Token>]],
	BNode                     => [-extends => [qw<Token>]],
	Variable                  => [-extends => [qw<Token>]],
	Number                    => [-extends => [qw<Token>]],
	Number_Double             => [-extends => [qw<Number>]],
	Number_Decimal            => [-extends => [qw<Number>]],
	Number_Integer            => [-extends => [qw<Number>]],
	Punctuation               => [-extends => [qw<Token>]],
	Path                      => [-extends => [qw<Token>]],
	Boolean                   => [-extends => [qw<Token>]],
	SparqlWord                => [-extends => [qw<Token>]],
	SparqlOrdering            => [-extends => [qw<Token>]],
	SparqlOperator            => [-extends => [qw<Token>]],
	IsOf                      => [-extends => [qw<Token>]],
	Language                  => [-extends => [qw<Token>]],
	Unknown                   => [-extends => [qw<Token>]],
	Whitespace                => [-extends => [qw<Token>]],
	Name                      => [-extends => [qw<Token>]],
	URIRef                    => [-extends => [qw<Token>], qw($uri $absolute_uri)],
	CURIE                     => [-extends => [qw<Token>], qw($absolute_uri)],
	String                    => [-extends => [qw<Token>], qw($quote_char $parts $language)],
	LongString                => [-extends => [qw<String>]],
	ShortString               => [-extends => [qw<String>]],
;

use Throwable::Factory
	Tokenization              => [qw( $remaining -caller )],
	NotImplemented            => [qw( -notimplemented )],
;

{
	no strict 'refs';
	*{Token."::TO_STRING"} = sub {
		sprintf "%s[%s]", $_[0]->TYPE, $_[0]->spelling
	};
	*{Token."::TO_HTML"}   = sub {
		require HTML::HTML5::Entities;
		sprintf "<span class=\"rdf_%s\">%s</span>", lc $_[0]->TYPE, HTML::HTML5::Entities::encode_entities($_[0]->spelling)
	};
	*{Whitespace."::TO_HTML"}   = sub {
		$_[0]->spelling;
	};
}

use Moo;

use constant {
	MODE_NTRIPLES       => 0,
	MODE_TURTLE         => 1,
	MODE_NOTATION_3     => 2,
	MODE_SPARQL_QUERY   => 4,
	MODE_SPARQL_UPDATE  => 8,
	MODE_SHORTHAND_RDF  => 16,
	MODE_PRETDSL        => 32,
};

my $default_mode = MODE_NTRIPLES | MODE_TURTLE | MODE_NOTATION_3
	| MODE_SPARQL_QUERY | MODE_SPARQL_UPDATE | MODE_SHORTHAND_RDF
	| MODE_PRETDSL;

has _remaining => (is => "rw");
has _tokens    => (is => "rw");
has _base      => (is => "rw");
has mode       => (is => "ro", default => sub { $default_mode });

# XXX - May be able to get better regexps from Trine?
my $nameStartChar  = qr{A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}};
my $nameStartChar2 = qr{A-Za-yz\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}};
my $nameChar       = qr{A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}\x{00B7}\x{203F}\x{2040}0-9-};

sub _peek
{
	my $self = shift;
	my ($regexp) = @_;
	$regexp = qr{^(\Q$regexp\E)} unless ref $regexp;
	
	if (my @m = (${$self->_remaining} =~ $regexp))
	{
		return \@m;
	}
	
	return;
}

sub _pull_token
{
	my $self = shift;
	my ($spelling, $class, %more) = @_;
	substr(${$self->_remaining}, 0, length $spelling, "");
	push @{$self->_tokens}, $class->new(spelling => $spelling, %more);
}

sub _pull_bnode
{
	my $self = shift;	
	${$self->_remaining} =~ m/^(_:[$nameStartChar][$nameChar]*)/
		? $self->_pull_token($1, BNode)
		: $self->_pull("_:", BNode)
}

sub _pull_variable
{
	my $self = shift;	
	${$self->_remaining} =~ m/^([\?\$][$nameStartChar][$nameChar]*)/
		? $self->_pull_token($1, Variable)
		: $self->_pull(substr(${$self->_remaining}, 0, 1), Variable)
}

sub _pull_whitespace
{
	my $self = shift;	
	$self->_pull_token($1, Whitespace)
		if ${$self->_remaining} =~ m/^(\s*)/sm;
}

sub _pull_uri
{
	my $self = shift;
	$self->_pull_token($1, URIRef)
		if ${$self->_remaining} =~ m/^(<(?:\\\\|\\>|\\<|[^<>\\]){0,1024}>)/;
}

sub _pull_curie
{
	my $self = shift;
	$self->_pull_token($1, CURIE)
		if ${$self->_remaining} =~ m/^(([$nameStartChar2][$nameChar]*)?:([$nameStartChar2][$nameChar]*)?)/;
}

sub _pull_shortstring
{
	my $self = shift;	
	my $quote_char = substr(${$self->_remaining}, 0, 1);
	$self->_pull_token($1, ShortString, quote_char => $quote_char)
		if ${$self->_remaining} =~ m/^($quote_char(?:\\\\|\\.|[^$quote_char])*?$quote_char)/;
}

sub _pull_longstring
{
	my $self = shift;	
	my $quote_char = substr(${$self->_remaining}, 0, 1);
	$self->_pull_token($1, LongString, quote_char => $quote_char)
		if ${$self->_remaining} =~ m/^($quote_char{3}.*?$quote_char{3})/ms;
}

sub tokenize
{
	my $self = shift;
	my ($text_ref, $base) = @_;
	$self->_remaining($text_ref);
	$self->_tokens([]);
	$self->_base($base // "http://www.example.net/");
	
	# Don't need to repeatedly call this method!
	my $mode = $self->mode;
	my $matches;
	
	while (length ${ $self->_remaining })
	{
		no warnings 'redefine';
		
		if ($self->_peek(' ') || $self->_peek("\n") || $self->_peek("\r") || $self->_peek("\t"))
		{
			$self->_pull_whitespace;
		}
		elsif ($self->_peek('{') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('{', Brace);
		}
		elsif ($self->_peek('}') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('}', Brace);
		}
		elsif ($self->_peek('[') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token('[', Bracket);
		}
		elsif ($self->_peek(']') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token(']', Bracket);
		}
		elsif ($self->_peek('(') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token('(', Parenthesis);
		}
		elsif ($self->_peek(')') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token(')', Parenthesis);
		}
		elsif ($self->_peek('^^'))
		{
			$self->_pull_token('^^', Datatype);
		}
		elsif ($self->_peek('^') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('^', Path);
		}
		elsif ($self->_peek('!') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('!', Path);
		}
		elsif ($self->_peek(','))
		{
			$self->_pull_token(',', Punctuation);
		}
		elsif ($self->_peek(';'))
		{
			$self->_pull_token(';', Punctuation);
		}
		elsif ($self->_peek('.'))
		{
			$self->_pull_token('.', Punctuation);
		}
		elsif ($self->_peek('@prefix') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token('@prefix', AtRule);
		}
		elsif ($self->_peek('@base') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token('@base', AtRule);
		}
		elsif ($self->_peek('@keywords') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('@keywords', AtRule);
		}
		elsif ($self->_peek('@forAll') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('@forAll', AtRule);
		}
		elsif ($self->_peek('@forSome') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('@forSome', AtRule);
		}
		elsif ($matches = $self->_peek(qr/^(\@[a-z0-9-]+)/i))
		{
			$self->_pull_token($matches->[0], Language);
		}
		elsif ($matches = $self->_peek(qr/^(#.*)(\r|\n|$)/ims))
		{
			$self->_pull_token($matches->[0], Comment);
		}
		elsif ($self->_peek('_:'))
		{
			$self->_pull_bnode;
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([$nameStartChar2][$nameChar]*)?:([$nameStartChar2][$nameChar]*)?/))
		{
			$self->_pull_curie;
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?([0-9]+\.[0-9]*e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?(\.[0-9]+e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?([0-9]+e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?([0-9]+\.[0-9]*))/))
		{
			$self->_pull_token($matches->[0], Number_Decimal);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?(\.[0-9]+))/))
		{
			$self->_pull_token($matches->[0], Number_Decimal);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([\-\+]?([0-9]+))/))
		{
			$self->_pull_token($matches->[0], Number_Integer);
		}
		elsif ($self->_peek('<'))
		{
			$self->_pull_uri;
		}
		elsif (($self->_peek('?') || $self->_peek('$')) && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_variable;
		}
		elsif (($self->_peek('*')) && ($mode & MODE_SPARQL_QUERY))
		{
			$self->_pull_token('*', Variable);
		}
		elsif (($self->_peek('"""') || $self->_peek("'''")) && ($mode & MODE_TURTLE))
		{
			$self->_pull_longstring;
		}
		elsif ($self->_peek('"') || $self->_peek("'"))
		{
			$self->_pull_shortstring;
		}
		elsif (($mode & MODE_SPARQL_QUERY) and $matches = $self->_peek(qr/^(prefix|base|select|distinct|from\s+named|from|where|graph|ask|describe|construct|filter|optional|union|unsaid|not\s+exists|order\s+by|limit|offset|reduced|project)/i))
		{
			$self->_pull_token($matches->[0], SparqlWord);
		}
		elsif (($mode & MODE_SPARQL_UPDATE) and $matches = $self->_peek(qr/^(insert|into|delete|load|modify|data|clear|silent)/i))
		{
			$self->_pull_token($matches->[0], SparqlWord);
		}
		elsif (($mode & MODE_SPARQL_QUERY) and $matches = $self->_peek(qr/^(asc|desc)/i))
		{
			$self->_pull_token($matches->[0], SparqlOrdering);
		}
		elsif (($mode & MODE_SPARQL_QUERY) and $matches = $self->_peek(qr/^(bound|isiri|isblank|isliteral|str|lang|datatype|\|\||\&\&|=|!|sameterm|langmatches|regex)/i))
		{
			$self->_pull_token($matches->[0], SparqlOperator);
		}
		elsif ($mode & MODE_TURTLE and $matches = $self->_peek(qr/^(true|false)\b/i))
		{
			$self->_pull_token($matches->[0], Boolean);
		}
		elsif ($self->_peek('a') && ($mode & MODE_TURTLE))
		{
			$self->_pull_token('a', Shorthand);
		}
		elsif ($self->_peek('=>') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('=>', Shorthand);
		}
		elsif ($self->_peek('<=') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('<=', Shorthand);
		}
		elsif ($self->_peek('=') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('=', Shorthand);
		}
		elsif ($self->_peek('is') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('is', IsOf);
		}
		elsif ($self->_peek('of') && ($mode & MODE_NOTATION_3))
		{
			$self->_pull_token('of', IsOf);
		}
		elsif (($mode & MODE_TURTLE) and $matches = $self->_peek(qr/^([$nameStartChar][$nameChar]*)/))
		{
			$self->_pull_token($matches->[0], Name);
		}
		elsif ($matches = $self->_peek(qr/^([^\s\r\n]+)[\s\r\n]/))
		{
			$self->_pull_token($matches->[0], Unknown);
		}		
		elsif ($matches = $self->_peek(qr/^([^\s\r\n]+)$/))
		{
			$self->_pull_token($matches->[0], Unknown);
		}
		else
		{
			Tokenization->throw(
				"Could not tokenise string!",
				remaining => ${ $self->_remaining },
			);
		}
	}
	
	return $self->_tokens;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Syntax::Highlight::RDF - syntax highlighting for various RDF-related formats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Syntax-Highlight-RDF>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

