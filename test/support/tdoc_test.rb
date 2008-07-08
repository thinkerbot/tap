require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class TDocTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_tap_test
  
  def setup
    super
    TDoc.clear
  end
  
  def teardown
    super
    TDoc.clear
  end
  
  #
  # TDoc.clear test
  #
  
  def test_clear_reinitialized_docs_to_empty_hash
    TDoc.docs[:key] = 'value'
    assert_equal({:key => 'value'}, TDoc.docs)
    
    TDoc.clear
    assert_equal({}, TDoc.docs)
  end

  #
  # TDoc.parse test
  #
  # 
  # def test_parse_returns_tdoc
  #   assert_equal TDoc, TDoc.parse("").class
  # end
  
  DESC_STR = [
    "not a comment # trailing comment",
    "# not part of desc",
    "# ::manifest summary string ",
    "# continuous",
    "# line one",
    "#",
    "#   indented line one",
    "#   indented line two",
    " #     ",
    "# line two      ",
    "    # with various whitespace      ",
    "#  indented line three    ",
    "  #    indented line four   ",
    "# continuous",
    "# line three"
  ].join("\n")
  
  EXPECTED_SUMMARY = "summary string"
  EXPECTED_DESC = [
    "continuous line one",
    "",
    "  indented line one",
    "  indented line two",
    "",
    "line two with various whitespace",
    " indented line three",
    "   indented line four",
    "continuous line three"
  ]
  
  # def test_parse_summary
  #   assert_equal EXPECTED_SUMMARY, TDoc.parse(DESC_STR).summary
  # end
  # 
  # def test_parse_desc
  #   assert_equal EXPECTED_DESC, TDoc.parse(DESC_STR).desc
  # end
  # 
  # def test_parse_desc_with_termination_sequence
  #   [
  #     DESC_STR + "\n# :startdoc:\n# ignored",
  #     DESC_STR + "\n# :stopdoc:\n# ignored",
  #     DESC_STR + "\nnot a comment # ignored\n# ignored",
  #     DESC_STR + "\n\n# ignored",
  #     DESC_STR + "\n  \t  \n# ignored"
  #   ].each do |desc_str|
  #     assert_equal EXPECTED_DESC, TDoc.parse(desc_str).desc, desc_str
  #   end  
  # end
  # 
  # def test_parse_removes_empty_lines_before_and_after_desc
  #   str = %Q{
  #     # ::manifest 
  #     # 
  #     # comment line one
  #     # continued line one
  #     #
  #     # comment line two
  #     # 
  #     #
  #   }
  #   assert_equal ["comment line one continued line one", "", "comment line two"], TDoc.parse(str).desc, str
  # end
  # 
  # # def test_parse_sets_class_name_if_specified
  # #   assert_equal "Some::Class", TDoc.parse(%Q{# Some::Class::manifest }).class_name
  # # end
  # 
  # USAGE_STR = [
  #    "not a comment # trailing comment",
  #    "# not part of usage",
  #    "# ::usage usage string ",
  #    "# not part of usage", 
  #  ].join("\n")
  #  EXPECTED_USAGE = "usage string"
  #  
  #  def test_parse_usage
  #    assert_equal EXPECTED_USAGE, TDoc.parse(USAGE_STR).usage
  #  end
  #  
  #  def test_usage_may_lead_or_follow_desc
  #    leading_str = DESC_STR + "\n" + USAGE_STR
  #    
  #    tdoc = TDoc.parse(leading_str)
  #    assert_equal EXPECTED_USAGE, tdoc.usage
  #    assert_equal EXPECTED_DESC, tdoc.desc
  #    
  #    trailing_str = USAGE_STR + "\n" + DESC_STR
  #    
  #    tdoc = TDoc.parse(trailing_str)
  #    assert_equal EXPECTED_USAGE, tdoc.usage
  #    assert_equal EXPECTED_DESC, tdoc.desc
  #  end
  #  
  #  def test_parse_yields_scanner_and_tdoc_to_block
  #    was_in_block = false
  #    TDoc.parse("") do |scanner, tdoc|
  #      assert_equal StringScanner, scanner.class
  #      assert_equal TDoc, tdoc.class
  #      was_in_block = true
  #    end
  #    
  #    assert was_in_block
  #  end
  #  
  #  def test_parse_speed
  #    benchmark_test(25) do |x|
  #      str = ("fiver" * 1000)
  #      n = 1000
  #      x.report("#{n} x #{str.length} chars") do 
  #        n.times { TDoc.parse(str) }
  #      end
  #      
  #      desc_use = DESC_STR + "\n" + USAGE_STR
  #      x.report("#{n} x #{desc_use.length} desc+use") do 
  #        n.times { TDoc.parse(desc_use) }
  #      end
  #      
  #      use_desc = USAGE_STR  + "\n" + DESC_STR
  #      x.report("#{n} x #{desc_use.length} use+desc") do 
  #        n.times { TDoc.parse(use_desc) }
  #      end
  #      
  #      both = str + desc_use
  #      x.report("#{n} x #{both.length} both") do 
  #        n.times { TDoc.parse(both) }
  #      end
  #    end
  #  end
  
  #
  # initialize test
  #
  
  def test_initialize
    t = TDoc.new 
    
    assert_nil t.summary
    assert t.desc.empty?
    assert_nil t.usage
    assert t.config.empty?
  end
  
end
