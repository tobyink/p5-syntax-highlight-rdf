package Syntax::Highlight::RDF;

use 5.010001;
use strict;
use warnings;

BEGIN {
	$Syntax::Highlight::RDF::AUTHORITY = 'cpan:TOBYINK';
	$Syntax::Highlight::RDF::VERSION   = '0.001';
}

use MooX::Struct -retain, -rw,
	Feature                   => [],
	Token                     => [-extends => [qw<Feature>], qw($spelling!)],
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
	Sparql                    => [-extends => [qw<Token>]],
	Sparql_Keyword            => [-extends => [qw<Sparql>]],
	Sparql_Operator           => [-extends => [qw<Sparql>]],
	Sparql_Function           => [-extends => [qw<Sparql>]],
	Sparql_Aggregate          => [-extends => [qw<Sparql_Function>]],
	Sparql_Ordering           => [-extends => [qw<Sparql_Function>]],
	IsOf                      => [-extends => [qw<Token>]],
	Language                  => [-extends => [qw<Token>]],
	Unknown                   => [-extends => [qw<Token>]],
	Whitespace                => [-extends => [qw<Token>]],
	Name                      => [-extends => [qw<Token>]],
	URIRef                    => [-extends => [qw<Token>], qw($absolute_uri)],
	CURIE                     => [-extends => [qw<Token>], qw($absolute_uri)],
	String                    => [-extends => [qw<Token>], qw($quote_char $parts $language)],
	LongString                => [-extends => [qw<String>]],
	ShortString               => [-extends => [qw<String>]],
	Structure_Start           => [-extends => [qw<Feature>], qw($end)],
	Structure_End             => [-extends => [qw<Feature>], q($start) => [weak_ref => 1]],
	PrefixDefinition_Start    => [-extends => [qw<Structure_Start>], qw($prefix $absolute_uri)],
	PrefixDefinition_End      => [-extends => [qw<Structure_End>]],
;

use Throwable::Factory
	Tokenization              => [qw( $remaining -caller )],
	NotImplemented            => [qw( -notimplemented )],
	WTF                       => [],
;

{
	use HTML::HTML5::Entities qw/encode_entities/;
	
	no strict 'refs';
	*{Feature    . "::tok"}        = sub { sprintf "%s~", $_[0]->TYPE };
	*{Token      . "::tok"}        = sub { sprintf "%s[%s]", $_[0]->TYPE, $_[0]->spelling };
	*{Whitespace . "::tok"}        = sub { $_[0]->TYPE };
	*{Feature    . "::TO_STRING"}  = sub { "" };
	*{Token      . "::TO_STRING"}  = sub { $_[0]->spelling };
	*{Token      . "::TO_HTML"}    = sub {
		sprintf "<span class=\"rdf_%s\">%s</span>", lc $_[0]->TYPE, encode_entities($_[0]->spelling)
	};
	*{Whitespace . "::TO_HTML"}  = sub { $_[0]->spelling };
	*{URIRef     . "::uri"}      = sub { my $u = $_[0]->spelling; substr $u, 1, length($u)-2 };  # XXX - unescape
	*{CURIE      . "::prefix"}   = sub { (split ":", $_[0]->spelling)[0] };
	*{CURIE      . "::suffix"}   = sub { (split ":", $_[0]->spelling)[1] };
	*{PrefixDefinition_Start . "::tok"} = sub {
		sprintf '%s{prefix:"%s",uri:"%s"}', $_[0]->TYPE, $_[0]->prefix, $_[0]->absolute_uri;
	};
	*{PrefixDefinition_End . "::tok"} = sub {
		sprintf '%s{prefix:"%s",uri:"%s"}', $_[0]->TYPE, $_[0]->start->prefix, $_[0]->start->absolute_uri;
	};
	*{CURIE      . "::tok"} = sub {
		sprintf '%s[%s]{uri:"%s"}', $_[0]->TYPE, $_[0]->spelling, $_[0]->absolute_uri//"???";
	};
	*{URIRef     . "::tok"} = sub {
		sprintf '%s[%s]{uri:"%s"}', $_[0]->TYPE, $_[0]->spelling, $_[0]->absolute_uri//"???";
	};
	*{Structure_Start . "::TO_HTML"} = sub {
		my @attrs = sprintf 'class="rdf_%s"', lc $_[0]->TYPE;
		sprintf "<span %s>", join " ", @attrs;
	};
	*{Structure_End . "::TO_HTML"} = sub {
		"</span>"
	};
	*{PrefixDefinition_Start . "::TO_HTML"} = sub {
		my @attrs = sprintf 'class="rdf_%s"', lc $_[0]->TYPE;
		push @attrs, sprintf 'data-rdf-prefix="%s"', encode_entities($_[0]->prefix) if defined $_[0]->prefix;
		push @attrs, sprintf 'data-rdf-uri="%s"', encode_entities($_[0]->absolute_uri) if defined $_[0]->absolute_uri;
		sprintf "<span %s>", join " ", @attrs;
	};
	*{CURIE . "::TO_HTML"} = sub {
		my @attrs = sprintf 'class="rdf_%s"', lc $_[0]->TYPE;
		push @attrs, sprintf 'data-rdf-prefix="%s"', encode_entities($_[0]->prefix) if defined $_[0]->prefix;
		push @attrs, sprintf 'data-rdf-suffix="%s"', encode_entities($_[0]->suffix) if defined $_[0]->suffix;
		push @attrs, sprintf 'data-rdf-uri="%s"', encode_entities($_[0]->absolute_uri) if defined $_[0]->absolute_uri;
		sprintf "<span %s>%s</span>", join(" ", @attrs), encode_entities($_[0]->spelling)
	};
	*{URIRef . "::TO_HTML"} = sub {
		my @attrs = sprintf 'class="rdf_%s"', lc $_[0]->TYPE;
		push @attrs, sprintf 'data-rdf-uri="%s"', encode_entities($_[0]->absolute_uri) if defined $_[0]->absolute_uri;
		sprintf "<span %s>%s</span>", join(" ", @attrs), encode_entities($_[0]->spelling)
	};
}

use Moo;

use IO::Detect qw( as_filehandle );

use constant {
	MODE_NTRIPLES       => 0,
	MODE_TURTLE         => 1,
	MODE_NOTATION_3     => 2,
	MODE_SPARQL         => 4,
	MODE_PRETDSL        => 8,
};

my $default_mode = MODE_NTRIPLES | MODE_TURTLE | MODE_NOTATION_3 | MODE_SPARQL | MODE_PRETDSL;

has _remaining => (is => "rw");
has _tokens    => (is => "rw");
has _base      => (is => "rw");
has mode       => (is => "ro", default => sub { $default_mode });

# XXX - May be able to get better regexps from Trine?
my $nameStartChar  = qr{A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}};
my $nameStartChar2 = qr{A-Za-yz\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}};
my $nameChar       = qr{A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}\x{00B7}\x{203F}\x{2040}0-9-};

our @sparqlQueryWord = qw(
	BASE
	PREFIX
	SELECT
	DISTINCT
	REDUCED
	AS
	CONSTRUCT
	WHERE
	DESCRIBE
	ASK
	FROM
	NAMED
	GROUP__BY
	HAVING
	ORDER__BY
	LIMIT
	OFFSET
	VALUES
	DEFAULT
	ALL
	OPTIONAL
	SERVICE
	BIND
	UNDEF
	MINUS
	FILTER
);

our @sparqlUpdateWord = qw(
	LOAD
	SILENT
	INTO
	CLEAR
	DROP
	CREATE
	ADD
	MOVE
	COPY
	INSERT__DATA
	DELETE__DATA
	DELETE__WHERE
	DELETE
	INSERT
	USING
);

our @sparqlOperator = qw(
	||
	&&
	=
	!=
	<
	>
	<=
	>=
	NOT__IN
	NOT
	IN
	+
	-
	*
	/
	!
);

our @sparqlFunction = qw(
	STR
	LANG
	LANGMATCHES
	DATATYPE
	BOUND
	IRI
	URI
	BNODE
	RAND
	ABS
	CEIL
	FLOOR
	ROUND
	CONCAT
	STRLEN
	UCASE
	LCASE
	ENCODE_FOR_URI
	CONTAINS
	STRSTARTS
	STRENDS
	STRBEFORE
	STRAFTER
	YEAR
	MONTH
	DAY
	HOURS
	MINUTES
	SECONDS
	TIMEZONE
	TZ
	NOW
	UUID
	STRUUID
	MD5
	SHA1
	SHA256
	SHA384
	SHA512
	COALESCE
	IF
	STRLANG
	STRDT
	sameTerm
	isIRI
	isURI
	isBLANK
	isLITERAL
	isNUMERIC
	REGEX
	SUBSTR
	REPLACE
	NOT__EXISTS
	EXISTS
);

our @sparqlAggregate = qw(
	COUNT
	SUM
	MIN
	MAX
	AVG
	SAMPLE
	GROUP_CONCAT
);

our @sparqlOrdering = qw(
	ASC
	DESC
);

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
	defined $spelling or WTF->throw("Tried to pull undef token!");
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

# XXX - this is probably too naive
sub _pull_shortstring
{
	my $self = shift;	
	my $quote_char = substr(${$self->_remaining}, 0, 1);
	$self->_pull_token($1, ShortString, quote_char => $quote_char)
		if ${$self->_remaining} =~ m/^($quote_char(?:\\\\|\\.|[^$quote_char])*?$quote_char)/;
}

# XXX - this is probably too naive
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
	my ($text_ref) = @_;
	$self->_remaining(
		ref($text_ref) eq 'SCALAR'
			? $text_ref
			: do { local $/; my $h = as_filehandle($text_ref); \(my $t = <$h>) }
	);
	$self->_tokens([]);
	
	# Calculate these each time in case somebody wants to play with
	# our variables!
	my $_regexify = sub
	{
		my @in     = @_;
		my $joined = join "|", map { s/__/\\s+/g; $_ } map quotemeta, @in;
		qr{^($joined)}i;
	};
	my $sparqlKeyword   = $_regexify->(@sparqlQueryWord, @sparqlUpdateWord);
	my $sparqlFunction  = $_regexify->(@sparqlFunction);
	my $sparqlAggregate = $_regexify->(@sparqlAggregate);
	my $sparqlOrdering  = $_regexify->(@sparqlOrdering);
	my $sparqlOperator  = $_regexify->(@sparqlOperator);
	
	# Don't need to repeatedly call this method!
	my $IS_NTRIPLES    = $self->mode & MODE_NTRIPLES;
	my $IS_TURTLE      = $self->mode & MODE_TURTLE;
	my $IS_NOTATION_3  = $self->mode & MODE_NOTATION_3;
	my $IS_SPARQL      = $self->mode & MODE_SPARQL;
	my $IS_PRETDSL     = $self->mode & MODE_PRETDSL;
	my $ABOVE_NTRIPLES = $IS_TURTLE || $IS_NOTATION_3 || $IS_SPARQL || $IS_PRETDSL;
	
	# Declare this ahead of time for use in the big elsif!
	my $matches;
	
	while (length ${ $self->_remaining })
	{
		if ($self->_peek(' ') || $self->_peek("\n") || $self->_peek("\r") || $self->_peek("\t"))
		{
			$self->_pull_whitespace;
		}
		elsif ($IS_NOTATION_3||$IS_SPARQL and $self->_peek('{'))
		{
			$self->_pull_token('{', Brace);
		}
		elsif ($IS_NOTATION_3||$IS_SPARQL and $self->_peek('}'))
		{
			$self->_pull_token('}', Brace);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek('['))
		{
			$self->_pull_token('[', Bracket);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek(']'))
		{
			$self->_pull_token(']', Bracket);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek('('))
		{
			$self->_pull_token('(', Parenthesis);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek(')'))
		{
			$self->_pull_token(')', Parenthesis);
		}
		elsif ($self->_peek('^^'))
		{
			$self->_pull_token('^^', Datatype);
		}
		elsif ($IS_NOTATION_3 and $matches = $self->_peek(qr/^([\!\^])/))
		{
			$self->_pull_token($matches->[0], Path);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\,\;])/))
		{
			$self->_pull_token($matches->[0], Punctuation);
		}
		elsif ($self->_peek('.'))
		{
			$self->_pull_token('.', Punctuation);
		}
		elsif ($IS_NOTATION_3||$IS_TURTLE and $matches = $self->_peek(qr/^(\@(?:prefix|base))/))
		{
			$self->_pull_token($matches->[0], AtRule);
		}
		elsif ($IS_NOTATION_3 and $matches = $self->_peek(qr/^(\@(?:keywords|forSome|forAll))/))
		{
			$self->_pull_token($matches->[0], AtRule);
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
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([$nameStartChar2][$nameChar]*)?:([$nameStartChar2][$nameChar]*)?/))
		{
			$self->_pull_curie;
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?([0-9]+\.[0-9]*e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?(\.[0-9]+e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?([0-9]+e[\-\+]?[0-9]+))/i))
		{
			$self->_pull_token($matches->[0], Number_Double);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?([0-9]+\.[0-9]*))/))
		{
			$self->_pull_token($matches->[0], Number_Decimal);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?(\.[0-9]+))/))
		{
			$self->_pull_token($matches->[0], Number_Decimal);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([\-\+]?([0-9]+))/))
		{
			$self->_pull_token($matches->[0], Number_Integer);
		}
		elsif ($self->_peek('<'))
		{
			$self->_pull_uri;
		}
		elsif ($IS_NOTATION_3||$IS_SPARQL and $self->_peek('?'))
		{
			$self->_pull_variable;
		}
		elsif ($IS_SPARQL and $self->_peek('$'))
		{
			$self->_pull_variable;
		}
		elsif ($IS_SPARQL and $self->_peek('*'))
		{
			$self->_pull_token('*', Variable);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek('"""') || $self->_peek("'''"))
		{
			$self->_pull_longstring;
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek("'"))
		{
			$self->_pull_shortstring;
		}
		elsif ($self->_peek('"'))
		{
			$self->_pull_shortstring;
		}
		elsif ($IS_SPARQL and $matches = $self->_peek($sparqlKeyword))
		{
			$self->_pull_token($matches->[0], Sparql_Keyword);
		}
		elsif ($IS_SPARQL and $matches = $self->_peek($sparqlFunction))
		{
			$self->_pull_token($matches->[0], Sparql_Function);
		}
		elsif ($IS_SPARQL and $matches = $self->_peek($sparqlAggregate))
		{
			$self->_pull_token($matches->[0], Sparql_Aggregate);
		}
		elsif ($IS_SPARQL and $matches = $self->_peek($sparqlOrdering))
		{
			$self->_pull_token($matches->[0], Sparql_Ordering);
		}
		elsif ($IS_SPARQL and $matches = $self->_peek($sparqlOperator))
		{
			$self->_pull_token($matches->[0], Sparql_Operator);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^(true|false)\b/i))
		{
			$self->_pull_token($matches->[0], Boolean);
		}
		elsif ($ABOVE_NTRIPLES and $self->_peek('a'))
		{
			$self->_pull_token('a', Shorthand);
		}
		elsif ($IS_NOTATION_3 and $matches = $self->_peek(qr/^(=|=>|<=)/))
		{
			$self->_pull_token($matches->[0], Shorthand);
		}
		elsif ($IS_NOTATION_3 and $matches = $self->_peek(qr/^(is|of)/i))
		{
			$self->_pull_token($matches->[0], IsOf);
		}
		elsif ($ABOVE_NTRIPLES and $matches = $self->_peek(qr/^([$nameStartChar][$nameChar]*)/))
		{
			$self->_pull_token($matches->[0], Name);
		}
		elsif ($matches = $self->_peek(qr/^([^\s\r\n]+)[\s\r\n]/ms))
		{
			$self->_pull_token($matches->[0], Unknown);
		}		
		elsif ($matches = $self->_peek(qr/^([^\s\r\n]+)$/ms))
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

sub _fixup
{
	my $self = shift;
	my ($base) = @_;
	$self->_fixup_urirefs($base);
	$self->_fixup_prefix_declarations;
	$self->_fixup_curies;
}

sub _resolve_uri
{
	shift;
	my ($relative, $base) = @_;
	return $relative unless length $base;
	
	# XXX - cope with situation where $base exists but is relative
	
	require URI;
	"URI"->new_abs(@_)->as_string;
}

sub _fixup_urirefs
{
	my $self = shift;
	my ($base) = @_;
	$base //= "";
	
	my $tokens = $self->_tokens;
	my $i = 0;
	while ($i < @$tokens)
	{
		my $t = $tokens->[$i];
		
		if ($t->isa(URIRef) and not defined $t->absolute_uri)
		{
			$t->absolute_uri($self->_resolve_uri($t->uri, $base));
		}
		elsif ( ($t->isa(Sparql_Keyword) and lc($t->spelling) eq 'base')
		or      ($t->isa(AtRule) and lc($t->spelling) eq '@base') )
		{
			# search ahead for the new base URI
			my $j = 1;
			while ($tokens->[$i+$j]->isa(Comment) || $tokens->[$i+$j]->isa(Whitespace))
			{
				$j++;
				last if !defined $tokens->[$i+$j];
			}
			if (defined $tokens->[$i+$j] and $tokens->[$i+$j]->can("uri"))
			{
				# new base URI found!
				$base = $self->_resolve_uri($tokens->[$i+$j]->uri, $base);
				$i += ($j - 1);
			}
		}
		
		$i++;
	}
}

sub _fixup_prefix_declarations
{
	my $self = shift;
	
	my $tokens = $self->_tokens;	
	my $i = 0;
	my $started;
	my @bits;
	while ($i < @$tokens)
	{
		my $t = $tokens->[$i];
		my $is_end;
		
		if ($t->isa(AtRule) and lc($t->spelling) eq '@prefix')
		{
			$started = $i;
			@bits    = $t;
		}
		elsif ($t->isa(Sparql_Keyword) and lc($t->spelling) eq 'PREFIX')
		{
			$started = $i;
			@bits    = $t;
		}
		elsif (defined $started and $t->isa(CURIE) || $t->isa(URIRef))
		{
			push @bits, $t;
		}
		elsif (defined $started and @bits==3 and $t->spelling eq "." and $bits[0]->isa(AtRule))
		{
			$is_end = 1;
		}
		
		if (!$is_end and defined $started and @bits==3 and $bits[0]->isa(Sparql_Keyword))
		{
			$is_end = 1;
		}
		
		if ($is_end)
		{
			my $END   = PrefixDefinition_End->new;
			my $START = PrefixDefinition_Start->new(
				prefix       => $bits[1]->prefix,
				absolute_uri => $bits[2]->absolute_uri,
				end          => $END
			);
			$END->start($START);
			
			$bits[1]->absolute_uri($bits[2]->absolute_uri);
			
			splice(@$tokens, $started, 0, $START); $i++;
			splice(@$tokens, $i+1,     0, $END); $i++;
		}
		
		$i++;
	}
}

sub _fixup_curies
{
	my $self = shift;
	
	my $map    = {};
	my $tokens = $self->_tokens;
	
	for my $t (@$tokens)
	{
		if ($t->isa(PrefixDefinition_End))
		{
			$map->{ $t->start->prefix } = $t->start->absolute_uri;
		}
		elsif ($t->isa(CURIE) and defined $t->prefix and exists $map->{$t->prefix})
		{
			$t->absolute_uri($map->{$t->prefix} . ($t->suffix//""));
		}
	}
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

