require  File.dirname(__FILE__) + '/../../tap_test_helper'
require 'tap/test/script_methods/regexp_escape'

class RegexpEscapeTest < Test::Unit::TestCase
  include Tap::Test::ScriptMethods
 
  def test_resolve_basic_escapes
    assert_equal "ab.*?c", RegexpEscape.resolve("ab:...:c")
    assert Regexp.new("ab.*?c") =~ "(arb lead) ab (arb string 123!) c (arb tail)"
    
    assert_equal "a\\.b.*?c\\.", RegexpEscape.resolve("a.b:...:c.")
    assert Regexp.new("a\\.b.*?c\\.") =~ "(arb lead) a.b (arb string 123!) c. (arb tail)"
    
    assert_equal "a\\.b.*?c.*?d", RegexpEscape.resolve("a.b:...:c:...:d")
    assert Regexp.new("a\\.b.*?c.*?d") =~ "(arb lead) a.b (arb string 123!) c (arb string 123!) d (arb tail)"
  end
  
  def test_resolve_substituent_escapes
    assert_equal 'ab\d\d:\d\d:\d\dc', RegexpEscape.resolve('ab:.(\d\d:\d\d:\d\d).:c')
    assert Regexp.new('ab\d\d:\d\d:\d\dc') =~ "(arb lead) ab08:08:08c (arb tail)"
  end
  
  #
  # matching test
  #
  
  def test_regexp_escape_matching
    regexp = RegexpEscape.new(%q{
some \regexp+(text)
:...:
:.(\w+).:
more :...: in*[the] m\iddle
another :.(\d\d:\d\d).: in the middle
})
    
    assert regexp =~ %q{
some \regexp+(text)
some arbitrary text
word
more arbitrary text in*[the] m\iddle
another 08:08 in the middle
}

    assert regexp =~ %q{
some \regexp+(text)

word
more  in*[the] m\iddle
another 08:08 in the middle
}

    assert regexp !~ %q{
some \regexp+(text)
some arbitrary text

more arbitrary text in*[the] m\iddle
another 08:08 in the middle
}

    assert regexp !~ %q{
some \regexp+(text)
some arbitrary text
word
more arbitrary text in*[the] m\iddle
another 0808 in the middle
}

  end

  #
  # to_s test
  #
  
  def test_to_s_returns_original_string
    assert_equal %q{some \regexp+(text):...:}, RegexpEscape.new(%q{some \regexp+(text):...:}).to_s
  end
end