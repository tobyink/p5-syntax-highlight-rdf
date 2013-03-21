<?php

require_once "Net/URL2.php";

define('N3_TOKENISER_CASE_SENSITIVE', true);
define('N3_TOKENISER_CASE_INSENSITIVE', false);

define('N3_TOKENISER_MODE_NTRIPLES', 0);
define('N3_TOKENISER_MODE_TURTLE', 1);
define('N3_TOKENISER_MODE_N3', 2);
define('N3_TOKENISER_MODE_SPARQL', 3);
define('N3_TOKENISER_MODE_SPARQL', 4);

class Notation3_Tokeniser
{
	private $remaining;
	private $encoding;
	private $tokens;
	private $mode;
	private $base; // no girls allowed!
	private $fixed_up = false;
	
	const nameStartChar  = 'A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}';
	const nameStartChar2 = 'A-Za-yz\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}';
	const nameChar       = 'A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}\x{00B7}\x{203F}\x{2040}0-9-';
	
	public function __construct ($string, $mode=N3_TOKENISER_MODE_N3, $base='http://example.com/', $encoding='utf-8')
	{
		$this->remaining = $string;
		$this->mode      = $mode;
		$this->base      = $base;
		$this->encoding  = $encoding;
		
		if (!mb_check_encoding($this->remaining, $this->encoding))
			throw new Exception("Wrong encoding!");
		
		if (strtolower($this->encoding) != 'utf-8')
		{
			$this->remaining = mb_convert_encoding($this->remaining, 'utf-8', $this->encoding);
			$this->encoding  = 'utf-8';
		}
	}
	
	public function get_tokens ()
	{
		if (empty($this->tokens))
			$this->tokenise();
		
		return $this->tokens;
	}
	
	public function get_html ()
	{
		$this->tokenise();
		$this->fixer_upper();
		
		$dialect = array(
			N3_TOKENISER_MODE_NTRIPLES  => 'ntriples',
			N3_TOKENISER_MODE_TURTLE    => 'turtle',
			N3_TOKENISER_MODE_N3        => 'notation3',
			N3_TOKENISER_MODE_SPARQL    => 'sparql',
			N3_TOKENISER_MODE_SPARUL    => 'sparul');
	
		$html = sprintf("<pre><code class=\"n3 n3-dialect-%s\">", $dialect[ $this->mode ]);
		foreach ($this->get_tokens() as $t)
			$html .= $t->to_HTML();
		$html .= "</code></pre>\n";
		
		return $html;
	}
	
	private function has_mode ($check)
	{
		return ($this->mode >= $check);
	}
	
	// This goes beyond what is strictly required of a tokeniser.
	public function fixer_upper ()
	{
		if ($this->fixed_up)
			return null;
		
		if (!$this->has_mode(N3_TOKENISER_MODE_TURTLE))
			return null;
	
		$tokens = $this->get_tokens();
		
		for ($i=0; isset($tokens[$i]); $i++)
		{
			$this_one = $tokens[$i];
			$next_one = $tokens[$i+1];
			
			if ($next_one instanceof Notation3_Token_Language
			&& ($this_one instanceof Notation3_Token_ShortString || $this_one instanceof Notation3_Token_LongString))
			{
				$this_one->language = substr($next_one->spelling, 1);
			}
		}
		
		$current_base = new Net_URL2($this->base);
		for ($i=0; isset($tokens[$i]); $i++)
		{
			$t = $tokens[$i];
			
			if (($t instanceof Notation3_Token_AtRule || $t instanceof Notation3_Token_SparqlWord) && $t->defines_base())
			{
				$u = $tokens[$i+1];
				if ($u instanceof Notation3_Token_Whitespace)
					$u = $tokens[$i+2];
				if ($u instanceof Notation3_Token_URIRef)
				{
					$new_base = new Net_URL2($u->uri);
					if ($new_base->isAbsolute())
						$current_base = $new_base;
					else
						$current_base = $current_base->resolve($new_base);
				}
			}
			elseif ($t instanceof Notation3_Token_URIRef)
			{
				$T = new Net_URL2($t->uri);
				if ($T->isAbsolute())
				{
					$t->absolute_uri = $t->uri;
				}
				else
				{
					$T_abs = $current_base->resolve($T);
					$t->absolute_uri = $T_abs->getURL();
					
					if (preg_match('/#$/',$t->uri) && !preg_match('/#$/',$t->absolute_uri))
						$t->absolute_uri .= '#';
				}
			}
		}
		
		$new_stream = array();
		while ($t = array_shift($tokens))
		{
			if (($t instanceof Notation3_Token_AtRule || $t instanceof Notation3_Token_SparqlWord) && $t->defines_prefix())
			{
				$prefix_rule  = $t;
				$whitespace_1 = ($tokens[0] instanceof Notation3_Token_Whitespace) ? array_shift($tokens) : false;
				if ($tokens[0] instanceof Notation3_Token_CURIE)
				{
					$curie        = array_shift($tokens);
					$whitespace_2 = false;
					$poop         = false;
				}
				elseif ($tokens[0] instanceof Notation3_Token_Name
				&&      $tokens[1] instanceof Notation3_Token_Whitespace
				&&      $tokens[2]->spelling === ':')
				{
					$curie        = array_shift($tokens);
					$whitespace_2 = array_shift($tokens);
					$poop         = array_shift($tokens);
					$poop         = new Notation3_Token_Unknown(':');
				}
				else
				{
					$new_stream[] = $prefix_rule;
					$new_stream[] = $whitespace_1;
					continue;
				}
				$whitespace_3 = ($tokens[0] instanceof Notation3_Token_Whitespace) ? array_shift($tokens) : false;
				$uri          = ($tokens[0] instanceof Notation3_Token_URIRef) ? array_shift($tokens) : false;
				$whitespace_4 = ($tokens[0] instanceof Notation3_Token_Whitespace) ? array_shift($tokens) : false;
				$dot          = true;
				if ($prefix_rule instanceof Notation3_Token_AtRule)
					$dot = ($tokens[0] instanceof Notation3_Token_Punctuation && $tokens[0]->spelling==='.') ? array_shift($tokens) : false;
				
				if ($prefix_rule && $curie && $uri && $dot)
				{
					$curie->defining = true;
				
					$prefix = ($curie instanceof Notation3_Token_Name) ? $curie->spelling : $curie->prefix;
					$full   = $uri->absolute_uri;

					$new_stream[] = new Notation3_Token_PrefixDefinition_Start($prefix, $full);
					foreach (array($prefix_rule, $whitespace_1, $curie, $whitespace_2, $poop, $whitespace_3, $uri, $whitespace_4, $dot) as $x)
						if ($x instanceof Notation3_Token_Abstract)
							$new_stream[] = $x;
					$new_stream[] = new Notation3_Token_PrefixDefinition_End($prefix, $full);
					continue;
				}
				else
				{
					foreach (array($prefix_rule, $whitespace_1, $curie, $whitespace_2, $poop, $whitespace_3, $uri, $whitespace_4, $dot) as $x)
						if ($x instanceof Notation3_Token_Abstract)
							$new_stream[] = $x;
					continue;
				}
			}
		
			$new_stream[] = $t;
		}
		
		$this->tokens = $new_stream;
		
		$mapping = array();
		foreach ($this->tokens as $t)
		{
			if ($t instanceof Notation3_Token_PrefixDefinition_End)
			{
				$mapping[ strlen($t->spelling) ? $t->spelling : '0' ] = $t->expansion;
			}
			elseif ($t instanceof Notation3_Token_CURIE)
			{
				if (isset($mapping[ strlen($t->prefix) ? $t->prefix : '0' ]))
				{
					$t->absolute_uri = $mapping[ strlen($t->prefix) ? $t->prefix : '0' ] . $t->suffix;
				}
			}
		}
		
		$this->fixed_up = true;
	}

	private function peek ($str, $case_sensitive=false)
	{
		$head = mb_substr($this->remaining, 0, strlen($str), $this->encoding);
		if ($case_sensitive && $str===$head)
			return true;
		if (!$case_sensitive && mb_strtolower($str, $this->encoding)===mb_strtolower($head, $this->encoding))
			return true;
		return false;
	}

	private function pull ($str, $case_sensitive=false)
	{
		$head = mb_substr($this->remaining, 0, strlen($str), $this->encoding);
		if ($case_sensitive && $str===$head)
		{
			$this->remaining = mb_substr($this->remaining, mb_strlen($head, $this->encoding), mb_strlen($this->remaining, $this->encoding), $this->encoding);
			return $head;
		}
		if (!$case_sensitive && mb_strtolower($str, $this->encoding)===mb_strtolower($head, $this->encoding))
		{
			$this->remaining = mb_substr($this->remaining, mb_strlen($head, $this->encoding), mb_strlen($this->remaining, $this->encoding), $this->encoding);
			return $head;
		}
		return false;
	}

	private function pulln ($n, $case_sensitive=false)
	{
		$head = mb_substr($this->remaining, 0, $n, $this->encoding);
		$this->remaining = mb_substr($this->remaining, mb_strlen($head, $this->encoding), mb_strlen($this->remaining, $this->encoding), $this->encoding);
		return $head;
	}

	private function pullt ($str, $token_type, $case_sensitive=false)
	{
		$head = $this->pull($str, $case_sensitive);
		if ($head===false)
			return false;
		
		$token_type = 'Notation3_Token_' . $token_type;
		$this->tokens[] = new $token_type ($head);
		return true;
	}
	
	private function pull_bnode ()
	{
		$matches = array();
		if (preg_match('/^(_:['.self::nameStartChar.']['.self::nameChar.']*)/u', $this->remaining, $matches))
			$this->tokens[] = new Notation3_Token_BNode ( $this->pull($matches[1]) );
		else
			$this->tokens[] = new Notation3_Token_BNode ( $this->pull('_:') );
	}

	private function pull_variable ()
	{
		$matches = array();
		if (preg_match('/^(\?['.self::nameStartChar.']['.self::nameChar.']*)/u', $this->remaining, $matches))
			$this->tokens[] = new Notation3_Token_Variable ( $this->pull($matches[1]) );
		else
			$this->tokens[] = new Notation3_Token_Variable ( $this->pull('_:') );
	}

	private function pull_whitespace ()
	{
		$matches = array();
		if (preg_match('/^([\s\r\n]+)/u', $this->remaining, $matches))
			$this->tokens[] = new Notation3_Token_Whitespace ( $this->pull($matches[1]) );
	}

	private function pull_uri ()
	{
		$matches = array();
		if (preg_match('/^(<[^>]{0,1024}>)/u', $this->remaining, $matches))
			$this->tokens[] = new Notation3_Token_URIRef ( $this->pull($matches[1]) );
	}

	private function pull_shortstring ()
	{
		$quote_char = $this->pulln(1);
		$string     = $quote_char;
		$is_quoted  = false;
		
		while (!empty($this->remaining))
		{
			$char = $this->pulln(1);

			if ($char===$quote_char && !$is_quoted)
			{
				$string .= $char;
				break;
			}
			elseif ($char==="\\" && !$is_quoted)
			{
				$string .= $char;
				$is_quoted = true;
			}
			elseif ($char==="\n" || $char==="\r")
			{
				break;
			}
			else
			{
				$string .= $char;
				$is_quoted = false;
			}
		}
		
		$this->tokens[] = new Notation3_Token_ShortString ( $string , $quote_char );
	}

	private function pull_longstring ()
	{
		$quote_chars     = $this->pulln(3);
		$end_quote_pos   = mb_strpos($this->remaining, $quote_chars, 0, $this->encoding);
		
		if ($end_quote_pos === false)
		{
			$guts            = $this->remaining;
			$this->remaining = '';
			$end_quote_chars = '';
		}
		else
		{
			$guts            = $this->pulln($end_quote_pos);
			$end_quote_chars = $this->pulln(3);
		}
		
		$this->tokens[] = new Notation3_Token_LongString ( $quote_chars.$guts.$end_quote_chars , $quote_chars , $guts, $end_quote_chars );
	}

	private function pull_curie ()
	{
		$matches = array();
		if (preg_match('/^((['.self::nameStartChar2.']['.self::nameChar.']*)?:(['.self::nameStartChar2.']['.self::nameChar.']*)?)/u', $this->remaining, $matches))
			$this->tokens[] = new Notation3_Token_CURIE ( $this->pull($matches[1]), $matches[2], $matches[3] );
	}

	public function tokenise ()
	{
		while (strlen($this->remaining))
		{
			$matches = array();
		
			if ($this->peek(' ') || $this->peek("\n") || $this->peek("\r") || $this->peek("\t"))
				$this->pull_whitespace();
		
			elseif ($this->peek('{') && $this->has_mode(N3_TOKENISER_MODE_N3))
				$this->pullt('{', 'Brace');

			elseif ($this->peek('}') && $this->has_mode(N3_TOKENISER_MODE_N3))
				$this->pullt('}', 'Brace');

			elseif ($this->peek('[') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt('[', 'Bracket');

			elseif ($this->peek(']') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt(']', 'Bracket');

			elseif ($this->peek('(') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt('(', 'Parenthesis');

			elseif ($this->peek(')') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt(')', 'Parenthesis');

			elseif ($this->peek('^^'))
				$this->pullt('^^', 'Datatype');

			elseif ($this->peek('^') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('^', 'Path');

			elseif ($this->peek('!') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('!', 'Path');

			elseif ($this->peek(','))
				$this->pullt(',', 'Punctuation');

			elseif ($this->peek(';'))
				$this->pullt(';', 'Punctuation');

			elseif ($this->peek('.'))
				$this->pullt('.', 'Punctuation');

			elseif ($this->peek('@prefix') && $this->has_mode(N3_TOKENISER_MODE_TURTLE) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('@prefix', 'AtRule');

			elseif ($this->peek('@base') && $this->has_mode(N3_TOKENISER_MODE_TURTLE) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('@base', 'AtRule');

			elseif ($this->peek('@keywords') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('@keywords', 'AtRule');

			elseif ($this->peek('@forAll') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('@forAll', 'AtRule');

			elseif ($this->peek('@forSome') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('@forSome', 'AtRule');

			elseif (preg_match('/^(\@[a-z0-9-]+)/iu', $this->remaining, $matches))
				$this->pullt($matches[1], 'Language');

			elseif (preg_match('/^(#.*)(\r|\n|$)/iu', $this->remaining, $matches))
				$this->pullt($matches[1], 'Comment');

			elseif ($this->peek('_:'))
				$this->pull_bnode();

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^(['.self::nameStartChar2.']['.self::nameChar.']*)?:(['.self::nameStartChar2.']['.self::nameChar.']*)?/u', $this->remaining))
				$this->pull_curie();

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?([0-9]+\.[0-9]*e[\-\+]?[0-9]+))/iu', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Double');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?(\.[0-9]+e[\-\+]?[0-9]+))/iu', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Double');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?([0-9]+e[\-\+]?[0-9]+))/iu', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Double');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?([0-9]+\.[0-9]*))/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Decimal');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?(\.[0-9]+))/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Decimal');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^([\-\+]?([0-9]+))/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Number_Integer');

			elseif ($this->peek('<'))
				$this->pull_uri();

			elseif (($this->peek('?') || $this->peek('$')) && $this->has_mode(N3_TOKENISER_MODE_N3))
				$this->pull_variable();

			elseif (($this->peek('*')) && $this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('*', 'Variable');

			elseif (($this->peek('"""') || $this->peek("'''")) && $this->has_mode(N3_TOKENISER_MODE_TURTLE) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pull_longstring();

			elseif ($this->peek('"') || $this->peek("'"))
				$this->pull_shortstring();

			elseif ($this->has_mode(N3_TOKENISER_MODE_SPARQL) && preg_match('/^(prefix|base|select|distinct|from\s+named|from|where|graph|ask|describe|construct|filter|optional|union|unsaid|not\s+exists|order\s+by|limit|offset|reduced|project)/ui', $this->remaining, $matches))
				$this->pullt($matches[1], 'SparqlWord');

			elseif ($this->has_mode(N3_TOKENISER_MODE_SPARUL) && preg_match('/^(insert|into|delete|load|modify|data|clear|silent)/ui', $this->remaining, $matches))
				$this->pullt($matches[1], 'SparqlWord');

			elseif ($this->has_mode(N3_TOKENISER_MODE_SPARQL) && preg_match('/^(asc|desc)/ui', $this->remaining, $matches))
				$this->pullt($matches[1], 'SparqlOrdering');
				
			elseif ($this->has_mode(N3_TOKENISER_MODE_SPARQL) && preg_match('/^(bound|isiri|isblank|isliteral|str|lang|datatype|\|\||\&\&|=|!|sameterm|langmatches|regex)/ui', $this->remaining, $matches))
				$this->pullt($matches[1], 'SparqlOperator');

			elseif ($this->peek('true') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt('true', 'Boolean');
				
			elseif ($this->peek('false') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt('false', 'Boolean');

			elseif ($this->peek('a') && $this->has_mode(N3_TOKENISER_MODE_TURTLE))
				$this->pullt('a', 'Shorthand');

			elseif ($this->peek('=>') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('=>', 'Shorthand');

			elseif ($this->peek('<=') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('<=', 'Shorthand');

			elseif ($this->peek('=') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('=', 'Shorthand');

			elseif ($this->peek('is') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('is', 'IsOf');

			elseif ($this->peek('of') && $this->has_mode(N3_TOKENISER_MODE_N3) && !$this->has_mode(N3_TOKENISER_MODE_SPARQL))
				$this->pullt('of', 'IsOf');

			elseif ($this->has_mode(N3_TOKENISER_MODE_TURTLE) && preg_match('/^(['.self::nameStartChar.']['.self::nameChar.']*)/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Name');

			elseif (preg_match('/^([^\s\r\n]+)[\s\r\n]/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Unknown');
					
			elseif (preg_match('/^([^\s\r\n]+)$/u', $this->remaining, $matches))
				$this->pullt($matches[1], 'Unknown');

			else
				throw new Exception("Could not tokenise string!");
		}
	}
	
}

abstract class Notation3_Token_Abstract
{
	public $spelling;
	
	public function __construct ($string)
	{
		$this->spelling = $string;
		return $this;
	}
	
	abstract public function to_HTML ();
}

class Notation3_Token_PrefixDefinition_Start extends Notation3_Token_Abstract
{
	public $expansion = null;
	
	public function __construct($p, $x)
	{
		parent::__construct($p);
		$this->expansion = $x;
	}
	
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-definition n3-definition-definesprefix-%s\">", $this->spelling);
	}
}

class Notation3_Token_PrefixDefinition_End extends Notation3_Token_PrefixDefinition_Start
{
	public function to_HTML ()
	{
		return "</span>";
	}
}

class Notation3_Token_Comment extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-comment\">%s</span>", $this->spelling);
	}
}

class Notation3_Token_Brace extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-brace\">%s</span>", $this->spelling);
	}
}

class Notation3_Token_Bracket extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-bracket\">%s</span>", $this->spelling);
	}
}

class Notation3_Token_Parenthesis extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-parenthesis\">%s</span>", $this->spelling);
	}
}

class Notation3_Token_Datatype extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-datatype\">%s</span>", $this->spelling);
	}
}

class Notation3_Token_AtRule extends Notation3_Token_Abstract
{
	public function defines_prefix ()
	{
		return (strtolower($this->spelling) === '@prefix');
	}

	public function defines_base ()
	{
		return (strtolower($this->spelling) === '@base');
	}

	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-atrule\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Shorthand extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-shorthand\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_BNode extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-bnode\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Variable extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<var class=\"n3-variable\">%s</var>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Number extends Notation3_Token_Abstract
{
	protected $klassen = 'n3-number';

	public function to_HTML ()
	{
		return sprintf("<span class=\"%s\">%s</span>",
			$this->klassen,
			htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Number_Double extends Notation3_Token_Number
{
	protected $klassen = 'n3-number n3-number-double';
}

class Notation3_Token_Number_Decimal extends Notation3_Token_Number
{
	protected $klassen = 'n3-number n3-number-decimal';
}

class Notation3_Token_Number_Integer extends Notation3_Token_Number
{
	protected $klassen = 'n3-number n3-number-integer';
}

class Notation3_Token_Punctuation extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-punc\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Path extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-path\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Boolean extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-boolean\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_SparqlWord extends Notation3_Token_Abstract
{
	public function defines_prefix ()
	{
		return (strtolower($this->spelling) === 'prefix');
	}

	public function defines_base ()
	{
		return (strtolower($this->spelling) === 'base');
	}

	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-sparqlword\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_SparqlOrdering extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-sparqlordering\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_SparqlOperator extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-sparqloperator\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_IsOf extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-isof\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Language extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("<span class=\"n3-language\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Unknown extends Notation3_Token_Abstract
{
	public function to_HTML ()
	{
		return sprintf("%s", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}

class Notation3_Token_Whitespace extends Notation3_Token_Unknown
{

}

class Notation3_Token_Name extends Notation3_Token_Abstract
{
	public $defining = false;

	public function to_HTML ()
	{
		return sprintf("<%s class=\"n3-name\">%s</%s>",
			($this->defining ? 'dfn' : 'span'),
			htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'),
			($this->defining ? 'dfn' : 'span'));
	}
}


class Notation3_Token_URIRef extends Notation3_Token_Abstract
{
	public $uri;
	public $absolute_uri;
	
	public function __construct ($string)
	{
		parent::__construct($string);
		
		$matches = array();
		if (preg_match('/^<([^>]*)>$/u', $string, $matches))
			$this->uri = $matches[1];
	}

	public function to_HTML ()
	{
		if (isset($this->absolute_uri) && isset($this->uri))
			return sprintf("<span class=\"n3-uri\"><span class=\"n3-uri-start\">&lt;</span><a class=\"n3-uri-ref\" href=\"%s\">%s</a><span class=\"n3-uri-end\">&gt;</span></span>",
				htmlentities($this->absolute_uri, ENT_COMPAT, 'utf-8'),
				htmlentities($this->uri, ENT_NOQUOTES, 'utf-8'));
		elseif (isset($this->uri))
			return sprintf("<span class=\"n3-uri n3-uri-nolink\"><span class=\"n3-uri-start\">&lt;</span><span class=\"n3-uri-ref\">%s</span><span class=\"n3-uri-end\">&gt;</span></span>", htmlentities($this->uri, ENT_NOQUOTES, 'utf-8'));
		else
			return sprintf("<span class=\"n3-uri n3-uri-nolink\">%s</span>", htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
	}
}


class Notation3_Token_CURIE extends Notation3_Token_Abstract
{
	public $absolute_uri;
	public $prefix;
	public $suffix;
	public $defining = false;
	
	public function __construct ($string, $p, $s)
	{
		parent::__construct($string);
		$this->prefix = $p;
		$this->suffix = $s;
	}

	public function to_HTML ()
	{
		if (isset($this->absolute_uri))
			return sprintf("<%s class=\"n3-curie n3-curie-usesprefix-%s\"><a href=\"%s\"><span class=\"n3-curie-prefix\">%s</span><span class=\"n3-curie-colon\">:</span><span class=\"n3-curie-suffix\">%s</span></a></%s>",
				($this->defining ? 'dfn' : 'span'),
				htmlentities($this->prefix, ENT_COMPAT, 'utf-8'),
				htmlentities($this->absolute_uri, ENT_COMPAT, 'utf-8'),
				htmlentities($this->prefix, ENT_NOQUOTES, 'utf-8'),
				htmlentities($this->suffix, ENT_NOQUOTES, 'utf-8'),
				($this->defining ? 'dfn' : 'span'));
		else
			return sprintf("<%s class=\"n3-curie n3-curie-nolink n3-curie-usesprefix-%s\"><span class=\"n3-curie-prefix\">%s</span><span class=\"n3-curie-colon\">:</span><span class=\"n3-curie-suffix\">%s</span></%s>",
				($this->defining ? 'dfn' : 'span'),
				htmlentities($this->prefix, ENT_COMPAT, 'utf-8'),
				htmlentities($this->prefix, ENT_NOQUOTES, 'utf-8'),
				htmlentities($this->suffix, ENT_NOQUOTES, 'utf-8'),
				($this->defining ? 'dfn' : 'span'));
	}
}

class Notation3_Token_ShortString extends Notation3_Token_Abstract
{
	private $quote_char;
	private $parts; // haha!
	public $language;

	public function __construct ($string, $quote_char)
	{
		parent::__construct($string);
		$this->quote_char = $quote_char;
		
		$this->parts = array();
		preg_match('/^('.$quote_char.')(.*)('.$quote_char.')$/', $string, $this->parts);
	}

	public function to_HTML ()
	{
		if (empty($this->parts))
			return sprintf("<span%s class=\"n3-lit n3-lit-funny\">%s</span>",
				(empty($this->language) ? '' : sprintf(' xml:lang="%s"', htmlentities($this->language, ENT_COMPAT, 'utf-8'))),
				htmlentities($this->spelling, ENT_NOQUOTES, 'utf-8'));
		else
			return sprintf("<span%s class=\"n3-lit\"><span class=\"n3-lit-quote n3-lit-quote-start n3-lit-quote-%s\">%s</span><span class=\"n3-lit-string\">%s</span><span class=\"n3-lit-quote n3-lit-quote-end n3-lit-quote-%s\">%s</span></span>",
				(empty($this->language) ? '' : sprintf(' xml:lang="%s"', htmlentities($this->language, ENT_COMPAT, 'utf-8'))),
				( $this->quote_char==="'" ? 'single' : 'double' ),
				htmlentities($this->parts[1], ENT_NOQUOTES, 'utf-8'),
				htmlentities($this->parts[2], ENT_NOQUOTES, 'utf-8'),
				( $this->quote_char==="'" ? 'single' : 'double' ),
				htmlentities($this->parts[3], ENT_NOQUOTES, 'utf-8'));
		
	}
}

class Notation3_Token_LongString extends Notation3_Token_Abstract
{
	private $parts; // haha!
	public $language;

	public function __construct ($string, $p1, $p2, $p3)
	{
		parent::__construct($string);
		
		$this->parts = array(
			1 => $p1,
			2 => $p2,
			3 => $p3);
	}

	public function to_HTML ()
	{
		return sprintf("<span%s class=\"n3-lit n3-lit-multiline%s\"><span class=\"n3-lit-quote n3-lit-quote-start n3-lit-quote-%s\">%s</span><span class=\"n3-lit-string\">%s</span><span class=\"n3-lit-quote n3-lit-quote-end n3-lit-quote-%s\">%s</span></span>",
			(empty($this->language) ? '' : sprintf(' xml:lang="%s"', htmlentities($this->language, ENT_COMPAT, 'utf-8'))),
			( empty($this->parts[3]) ? ' n3_lit_funny' : '' ),
			( $this->parts[1]==="'''" ? 'single' : 'double' ),
			htmlentities($this->parts[1], ENT_NOQUOTES, 'utf-8'),
			htmlentities($this->parts[2], ENT_NOQUOTES, 'utf-8'),
			( $this->parts[1]==="'''" ? 'single' : 'double' ),
			htmlentities($this->parts[3], ENT_NOQUOTES, 'utf-8'));
	}
}

print "<html>\n";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"n3.css\" />\n";
print "<script type=\"text/javascript\" src=\"jquery-1.3.2.min.js\"></script>\n";
print "<script type=\"text/javascript\" src=\"n3.js\"></script>\n";

$test = new Notation3_Tokeniser(
"@base <http://buzzword.org.uk/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex  : <http://example.com/vocab#> .
@prefix farm: <farm#> .

# this is a comment

{ ?foo
	a farm:Cow , <http://example.com/Cow> ; # another comment
	farm:age 3.141592 ;
	foaf:name 'Daisy O\\'Brian' ;
	foaf:plan \"\"\"Eat grass,
Make milk.\"\"\"@en-gb . } => { ?foo ex:owner [ foaf:name \"Farmer O\'Brien\" ] . } .");
print $test->get_html();

print "<hr/>\n";

$test = new Notation3_Tokeniser(
"PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT *
WHERE {
  ?person foaf:name ?name .
}
ORDER BY ASC(?name)", N3_TOKENISER_MODE_SPARQL);
print $test->get_html();

print "</html>\n";
