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
  
  def test_parse_returns_tdoc
    assert_equal TDoc, TDoc.parse("").class
  end
  
  DESC_STR = [
    "not a comment # trailing comment",
    "# not part of desc",
    "# :manifest: summary string ",
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
  
  def test_parse_summary
    assert_equal EXPECTED_SUMMARY, TDoc.parse(DESC_STR).summary
  end
  
  def test_parse_desc
    assert_equal EXPECTED_DESC, TDoc.parse(DESC_STR).desc

    desc_str = DESC_STR + %Q{
      # :startdoc:
      # ignored
    }
    assert_equal EXPECTED_DESC, TDoc.parse(desc_str).desc

    desc_str = DESC_STR + %Q{
      not a comment # trailing comment
    }
    assert_equal EXPECTED_DESC, TDoc.parse(desc_str).desc
  end
  
  USAGE_STR = [
    "not a comment # trailing comment",
    "# not part of usage",
    "# :Usage: usage string ",
    "# not part of usage", 
  ].join("\n")
  EXPECTED_USAGE = "usage string"
  
  def test_parse_usage
    assert_equal EXPECTED_USAGE, TDoc.parse(USAGE_STR).usage
  end
  
  def test_usage_may_lead_or_follow_desc
    leading_str = DESC_STR + "\n" + USAGE_STR
    
    tdoc = TDoc.parse(leading_str)
    assert_equal EXPECTED_USAGE, tdoc.usage
    assert_equal EXPECTED_DESC, tdoc.desc
    
    trailing_str = USAGE_STR + "\n" + DESC_STR
    
    tdoc = TDoc.parse(trailing_str)
    assert_equal EXPECTED_USAGE, tdoc.usage
    assert_equal EXPECTED_DESC, tdoc.desc
  end
  
  def test_parse_yields_scanner_and_tdoc_to_block
    was_in_block = false
    TDoc.parse("") do |scanner, tdoc|
      assert_equal StringScanner, scanner.class
      assert_equal TDoc, tdoc.class
      was_in_block = true
    end
    
    assert was_in_block
  end
  
  def test_parse_speed
    benchmark_test(25) do |x|
      str = ("fiver" * 1000)
      n = 1000
      x.report("#{n} x #{str.length} chars") do 
        n.times { TDoc.parse(str) }
      end
      
      desc_use = DESC_STR + "\n" + USAGE_STR
      x.report("#{n} x #{desc_use.length} desc+use") do 
        n.times { TDoc.parse(desc_use) }
      end
      
      use_desc = USAGE_STR  + "\n" + DESC_STR
      x.report("#{n} x #{desc_use.length} use+desc") do 
        n.times { TDoc.parse(use_desc) }
      end
      
      both = str + desc_use
      x.report("#{n} x #{both.length} both") do 
        n.times { TDoc.parse(both) }
      end
    end
  end

  #
  # TDoc[] test
  #
  
  # def test_get_with_filepath_returns_tdoc_for_filepath
  #   path = method_tempfile do |file|
  #     file << DESC_STR
  #   end
  #   assert File.exists?(path)
  #   
  #   tdoc = TDoc[path]
  #   
  #   assert_equal TDoc, tdoc.class
  #   assert_equal EXPECTED_DESC, tdoc.desc 
  # end
  # 
  # def test_get_with_filepath_returns_tdoc_for_filepath
  #   path = method_tempfile do |file|
  #     file << DESC_STR
  #   end
  #   assert File.exists?(path)
  #   
  #   tdoc = TDoc[path]
  #   
  #   assert_equal TDoc, tdoc.class
  #   assert_equal EXPECTED_DESC, tdoc.desc 
  # end
  # 
  # def test_get_stores_tdoc_in_docs_by_expaned_path
  #   path = method_tempfile {|file| }
  #   assert File.exists?(path)
  #   
  #   relative_filepath = Tap::Root.relative_filepath(".", path)
  #   tdoc = TDoc[relative_filepath]
  #   
  #   assert_equal({path => tdoc}, TDoc.docs)
  # end
  # 
  # def test_get_returns_existing_tdoc_regardless_of_input_type
  #   tdoc = TDoc.new
  #   TDoc.docs[:key] = tdoc
  # 
  #   assert_equal(tdoc, TDoc[:key])
  # end
  # 
  # def test_get_raises_error_for_non_existing_non_file_non_class_inputs
  #   path = method_tempfile
  #   
  #   assert_equal({}, TDoc.docs)
  #   assert !File.exists?(path)
  #   assert_raise(ArgumentError) { TDoc[path] }
  #   assert_raise(ArgumentError) { TDoc[:key] }
  # end
  # 
  # class SourceFileClass
  #   class << self
  #     attr_accessor :source_file
  #   end
  # end
  # 
  # def test_get_returns_doc_for_class_source_file_if_specified
  #   path = method_tempfile {|file| }
  #   SourceFileClass.source_file = path
  #   
  #   tdoc = TDoc[SourceFileClass]
  #   assert_equal({path => tdoc}, TDoc.docs)
  # end
  # 
  # class NoSourceFileClass
  #   class << self
  #     attr_reader :source_file
  #   end
  # end
  # 
  # def test_get_looks_along_search_paths_for_class_rb_file_as_source_file_if_unspecified
  #   search_paths = [method_dir(:output)]
  #   path = method_filepath(:output, NoSourceFileClass.to_s.underscore + ".rb")
  #   unless File.exists?(path)
  #     FileUtils.mkdir_p(File.dirname(path))
  #     FileUtils.touch(path)
  #   end
  # 
  #   tdoc = TDoc[NoSourceFileClass, search_paths]
  #   assert_equal({path => tdoc}, TDoc.docs)
  # end
  # 
  # class NoSourceFileAttributeClass
  # end
  # 
  # def test_get_looks_along_search_paths_for_class_rb_file_as_source_file_if_unavailable
  #   search_paths = [method_dir(:output)]
  #   path = method_filepath(:output, NoSourceFileAttributeClass.to_s.underscore + ".rb")
  #   unless File.exists?(path)
  #     FileUtils.mkdir_p(File.dirname(path))
  #     FileUtils.touch(path)
  #   end
  # 
  #   tdoc = TDoc[NoSourceFileAttributeClass, search_paths]
  #   assert_equal({path => tdoc}, TDoc.docs)
  # end
  # 
  # def test_get_raises_error_if_multiple_source_files_are_found
  #   search_paths = [method_dir(:output, 'a'), method_dir(:output, 'b')]
  #   path_a = method_filepath(:output, 'a', NoSourceFileClass.to_s.underscore + ".rb")
  #   unless File.exists?(path_a)
  #     FileUtils.mkdir_p(File.dirname(path_a))
  #     FileUtils.touch(path_a)
  #   end
  #   
  #   path_b = method_filepath(:output, 'b', NoSourceFileClass.to_s.underscore + ".rb")
  #   unless File.exists?(path_b)
  #     FileUtils.mkdir_p(File.dirname(path_b))
  #     FileUtils.touch(path_b)
  #   end
  #   
  #   assert_raise(ArgumentError) { TDoc[NoSourceFileClass, search_paths] }
  # end
  # 
  # def test_get_raises_error_if_no_source_file_is_found
  #   assert_raise(ArgumentError) { TDoc[NoSourceFileClass] }
  # end
  
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
 
# # = Section One
# # section one
# #
# # == Section Two
# # section two
# # line two
# class TaskDocumentation < Tap::Task
#   config :c_nodoc, 'value'                    # :nodoc:
#   config(:c_accessor, 'value')                # c_accessor
#   config(:c_validation, 'value') {|value| }   # c_validation
#   
#   config :c, 'value'        # c
#   
#   # c_conventional
#   config :c_conventional, 'value'
#   config :c_without_doc, 'value'
#  
#   # c_multiline1
#   config(:c_multiline, 'value' )                 # c_multiline2
# 
#   config :alt_c, 'value'                         # alt_c
#   config :alt_c_validation, 'value'  do |value|  # alt_c_validation
#   end
#   config :alt_c_without_value                             # alt_c_without_value
#   config :alt_c_validation_without_value   do |value|     # alt_c_validation_without_value
#   end
#   
#   # attr_accessor
#   attr_accessor :attr_accessor                   # ignored
#   attr_accessor :attr_accessor_without_doc
#   
#   # multi_attr_accessor
#   attr_accessor :multi_attr_accessor1, :multi_attr_accessor2
#   
#   config = [:is, :not, :documented]
#   attr_accessor = [:is, :not, :documented]
# 
#   def process(input)
#     config(:is, :not, :documented)
#     config :is, :not, :documented
#     declare_config :is, :not, :documented
#   end
# 
#   def config(*args)
#   end
#   
# end
# 
# # nested doc
# module Nested
#   # class doc
#   class Klass
#   end
#   
#   # mod doc
#   module Mod
#   end
# end
# 
# # class NotATask
# #   class << self
# #     def config(*args)
# #     end
# #   end
# #   
# #   config = "is not documented"
# # 
# #   config :is, :documented
# #   
# #   config = [:is, :not, :documented]
# # end
# 
# class TDocTest < Test::Unit::TestCase
#   include Tap::Test::SubsetMethods
# 
#   condition(:irb_variant) { env('tdoc_with_irb') }
#   if satisfied?(:irb_variant)
#     require 'irb'
#   end
#     
#   require 'tap/support/tdoc'
#   include Tap::Support
#     
#   TDoc.document(__FILE__)
#   
#    #
#    # RDoc RubyLex and RubyToken redefinition test
#    #
#    
#    def test_rubylex_and_rubytoken_redefinition   
#      filepath = __FILE__  
#      tl = RDoc::TopLevel.new(filepath)
#      stats = RDoc::Stats.new
#      options = Options.instance
#      parser = RDoc::RubyParser.new(tl, filepath, File.read(filepath), options, stats)
#      
#      assert Tap::Support::TDoc::ConfigParser.included_modules.include?(RDoc::RubyToken)
#      assert RDoc::RubyParser.included_modules.include?(RDoc::RubyToken)
#      assert_equal RDoc::RubyLex, parser.instance_variable_get("@scanner").class
#      
#      if satisfied?(:irb_variant)
#        assert_not_equal RubyToken, RDoc::RubyToken
#        assert_not_equal RubyLex, RDoc::RubyLex
#        assert RubyLex.included_modules.include?(RubyToken)
#        assert !RubyLex.included_modules.include?(RDoc::RubyLex)
#      else
#        flunk unless !Object.const_defined?(:RubyToken) || RubyToken == RDoc::RubyToken
#        flunk unless !Object.const_defined?(:RubyLex) || RubyLex == RDoc::RubyLex
#      end
#    end
#   
#    #
#    # [] tests
#    #
#    
#    def test_get_class_documentation
#      c = TDoc[TaskDocumentation]
#      assert_equal RDoc::NormalClass, c.class
#      assert_equal "# = Section One\n# section one\n#\n# == Section Two\n# section two\n# line two\n", c.comment
#      
#      
#      c = TDoc[Nested]
#      assert_equal RDoc::NormalModule, c.class
#      assert_equal "# nested doc\n", c.comment
#      
#      c = TDoc[Nested::Klass]
#      assert_equal RDoc::NormalClass, c.class
#      assert_equal "# class doc\n", c.comment
#      
#      c = TDoc[Nested::Mod]
#      assert_equal RDoc::NormalModule, c.class
#      assert_equal "# mod doc\n", c.comment
#    end
#    
#    def test_get_documentation_works_for_strings_and_constants
#      assert_equal RDoc::NormalClass, TDoc[Nested::Klass].class
#      assert_equal TDoc["Nested::Klass"].object_id, TDoc[Nested::Klass].object_id
#    end
#    
#    def test_configs_are_documented
#      c = TDoc[TaskDocumentation]
#      
#      attributes = c.attributes.collect do |attribute|
#        case attribute
#        when TDoc::ConfigAttr
#          {:comment => attribute.original_comment,
#          :name => attribute.name,  
#          :rw => attribute.rw, 
#          :text => attribute.text,
#          :default => attribute.default}
#        else
#          {:comment => attribute.comment,
#          :name => attribute.name,  
#          :rw => attribute.rw, 
#          :text => attribute.text}
#        end
#      end
#      
#      expected_attributes.each_with_index do |expected, i|
#        assert_equal expected, attributes[i], "unequal attribute (index=#{i})"
#      end
#      assert_equal expected_attributes.length, attributes.length
#    end
#    
#    #
#    # accessor extensions
#    #
#    
#    def test_comment_sections
#      c = TDoc[TaskDocumentation]
#      
#      assert c.respond_to?(:comment_sections)
#      assert_equal({
#        "Section One" => "# section one\n#\n",
#        "Section Two" => "# section two\n# line two\n"},
#      c.comment_sections)
#      
#      assert_equal({
#        "Section Two" => "# section two\n# line two\n"},
#      c.comment_sections(/two/i))
#      
#      assert_equal({
#        "Section Two" => "section two\nline two"},
#      c.comment_sections(/two/i, true))
#    end
#    
#    # def test_collect_configurations
#    #   c = TDoc.document(TaskDocumentation, __FILE__)
#    #   assert_equal expected_attributes[0..-5], TDoc.collect_configurations(c)
#    # end
#    # 
#    # def test_collect_attributes
#    #   c = TDoc.document(TaskDocumentation, __FILE__)
#    #   assert_equal expected_attributes[-4..-1], TDoc.collect_attributes(c)
#    # end
#    
#    def expected_attributes 
#      @expected_attributes ||= [{
#        :comment=>nil,
#        :name=>"c_accessor",
#        :rw=>"RW",
#        :text=>"# c_accessor",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"c_validation",
#        :rw=>"RW",
#        :text=>"# c_validation",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"c",
#        :rw=>"RW",
#        :text=>"# c",
#        :default => "'value'"},
#      {
#        :comment=>"# c_conventional\n",
#        :name=>"c_conventional",
#        :rw=>"RW",
#        :text=>"",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"c_without_doc",
#        :rw=>"RW",
#        :text=>"",
#        :default => "'value'"},
#      {
#        :comment=>"# c_multiline1\n",
#        :name=>"c_multiline",
#        :rw=>"RW",
#        :text=>"# c_multiline2",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"alt_c",
#        :rw=>"RW",
#        :text=>"# alt_c",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"alt_c_validation",
#        :rw=>"RW",
#        :text=>"# alt_c_validation",
#        :default => "'value'"},
#      {
#        :comment=>nil,
#        :name=>"alt_c_without_value",
#        :rw=>"RW",
#        :text=>"# alt_c_without_value",
#        :default => nil},
#      {
#        :comment=>nil,
#        :name=>"alt_c_validation_without_value",
#        :rw=>"RW",
#        :text=>"# alt_c_validation_without_value",
#        :default => nil},
#      {
#        :comment=>"# attr_accessor\n",
#        :name=>"attr_accessor",
#        :rw=>"RW",
#        :text=>"# ignored"},
#      {
#        :comment=>nil,
#        :name=>"attr_accessor_without_doc",
#        :rw=>"RW",
#        :text=>""},
#      {
#        :comment=>"# multi_attr_accessor\n",
#        :name=>"multi_attr_accessor1",
#        :rw=>"RW",
#        :text=>""},
#      {
#        :comment=>"# multi_attr_accessor\n",
#        :name=>"multi_attr_accessor2",
#        :rw=>"RW",
#        :text=>""}]
#    end
#    
#    #
#    # NotATask documentation
#    #
#    
#    # def test_not_a_task_document
#    #   c = TDoc.document(NotATask, __FILE__)
#    #   
#    #   assert_equal RDoc::NormalClass, c.class
#    #   assert_equal "", c.comment
#    #   
#    #   attributes = c.attributes.collect do |attribute|
#    #     case attribute
#    #     when TDoc::ConfigAttr
#    #     {:comment => attribute.original_comment,
#    #     :name => attribute.name,  
#    #     :rw => attribute.rw, 
#    #     :text => attribute.text}
#    #     else
#    #       {:comment => attribute.comment,
#    #       :name => attribute.name,  
#    #       :rw => attribute.rw, 
#    #       :text => attribute.text}
#    #     end
#    #   end
#    #   
#    #   not_a_task_expected_attributes.each_with_index do |expected, i|
#    #     assert_equal expected, attributes[i], "unequal attribute (index=#{i})"
#    #   end
#    #   assert_equal not_a_task_expected_attributes.length, attributes.length
#    # end
#    
#    # def not_a_task_expected_attributes 
#    #   @not_a_task_expected_attributes ||= [{
#    #   :comment=>nil,
#    #   :name=>"is",
#    #   :rw=>"RW",
#    #   :text=>""},
#    #  {
#    #   :comment=>nil,
#    #   :name=>"documented",
#    #   :rw=>"RW",
#    #   :text=>""}]
#    # end
# end
