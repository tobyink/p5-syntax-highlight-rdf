use 5.008;
use strict;
use warnings;

{
	package Syntax::Highlight::JSON2;

	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '0.001';
	
	use MooX::Struct -retain, -rw,
		Feature                   => [],
		Token                     => [-extends => [qw<Feature>], qw($spelling!)],
		Brace                     => [-extends => [qw<Token>]],
		Bracket                   => [-extends => [qw<Token>]],
		String                    => [-extends => [qw<Token>]],
		Number                    => [-extends => [qw<Token>]],
		Number_Double             => [-extends => [qw<Number>]],
		Number_Decimal            => [-extends => [qw<Number>]],
		Number_Integer            => [-extends => [qw<Number>]],
		Punctuation               => [-extends => [qw<Token>]],
		Keyword                   => [-extends => [qw<Token>]],
		Boolean                   => [-extends => [qw<Keyword>]],
		Whitespace                => [-extends => [qw<Token>]],
		Unknown                   => [-extends => [qw<Token>]],
	;

	use Throwable::Factory
		Tokenization              => [qw( $remaining -caller )],
		NotImplemented            => [qw( -notimplemented )],
		WTF                       => [],
		WrongInvocant             => [qw( -caller )],
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
			sprintf "<span class=\"json_%s\">%s</span>", lc $_[0]->TYPE, encode_entities($_[0]->spelling)
		};
		*{Whitespace . "::TO_HTML"}  = sub { $_[0]->spelling };
	}

	use Moo;

	has _tokens     => (is => 'rw');
	has _remaining  => (is => 'rw');
	
	use IO::Detect qw( as_filehandle );
		
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

	sub _pull_whitespace
	{
		my $self = shift;
		$self->_pull_token($1, Whitespace)
			if ${$self->_remaining} =~ m/^(\s*)/sm;
	}
	
	sub _pull_string
	{
		my $self = shift;
		# Extract string with escaped characters
		${$self->_remaining} =~ m#^("((?:[^\x00-\x1F\\"]|\\(?:["\\/bfnrt]|u[[:xdigit:]]{4})){0,32766})*")#
			? $self->_pull_token($1, String)
			: $self->_pull_token('"', Unknown);
	}
	
	sub tokenize
	{
		my $self = shift;
		ref $self or WrongInvocant->throw("this is an object method!");
		
		my ($text_ref) = @_;
		$self->_remaining(
			ref($text_ref) eq 'SCALAR'
				? $text_ref
				: do { local $/; my $h = as_filehandle($text_ref); \(my $t = <$h>) }
		);
		$self->_tokens([]);
		
		# Declare this ahead of time for use in the big elsif!
		my $matches;
		
		while (length ${ $self->_remaining })
		{
			$self->_pull_whitespace if $self->_peek(qr{^\s+});
			
			if ($matches = $self->_peek(qr!^([\,\:])!))
			{
				$self->_pull_token($matches->[0], Punctuation);
			}
			elsif ($matches = $self->_peek(qr!^([\[\]])!))
			{
				$self->_pull_token($matches->[0], Bracket);
			}
			elsif ($matches = $self->_peek(qr!^( \{ | \} )!x))
			{
				$self->_pull_token($matches->[0], Brace);
			}
			elsif ($self->_peek("null"))
			{
				$self->_pull_token("null", Keyword);
			}
			elsif ($matches = $self->_peek(qr!^(true|false)!))
			{
				$self->_pull_token($matches->[0], Boolean);
			}
			elsif ($self->_peek('"'))
			{
				$self->_pull_string;
			}
			elsif ($matches = $self->_peek(qr!^([-]?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?)!))
			{
				my $n = $matches->[0];
				if ($n =~ /e/i)    { $self->_pull_token($n, Number_Double) }
				elsif ($n =~ /\./) { $self->_pull_token($n, Number_Decimal) }
				else               { $self->_pull_token($n, Number_Integer) }
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
			
			$self->_pull_whitespace if $self->_peek(qr{^\s+});
		}
		
		return $self->_tokens;
	}

	sub highlight
	{
		my $self = shift;
		ref $self or WrongInvocant->throw("this is an object method!");
		$self->tokenize(@_);
		return join "", map $_->TO_HTML, @{$self->_tokens};
	}
}

1;
