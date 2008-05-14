require  File.join(File.dirname(__FILE__), '../tap_test_helper')

# = Section One
# section one
#
# == Section Two
# section two
# line two
class TaskDocumentation < Tap::Task
  config :c_nodoc, 'value'                    # :nodoc:
  config(:c_accessor, 'value')                # c_accessor
  config(:c_validation, 'value') {|value| }   # c_validation
  
  config :c, 'value'        # c
  
  # c_conventional
  config :c_conventional, 'value'
  config :c_without_doc, 'value'
 
  # c_multiline1
  config(:c_multiline, 'value' )                 # c_multiline2

  config :alt_c, 'value'                         # alt_c
  config :alt_c_validation, 'value'  do |value|  # alt_c_validation
  end
  config :alt_c_without_value                             # alt_c_without_value
  config :alt_c_validation_without_value   do |value|     # alt_c_validation_without_value
  end
  
  # attr_accessor
  attr_accessor :attr_accessor                   # ignored
  attr_accessor :attr_accessor_without_doc
  
  # multi_attr_accessor
  attr_accessor :multi_attr_accessor1, :multi_attr_accessor2
  
  config = [:is, :not, :documented]
  attr_accessor = [:is, :not, :documented]

  def process(input)
    config(:is, :not, :documented)
    config :is, :not, :documented
    declare_config :is, :not, :documented
  end

  def config(*args)
  end
  
end

# nested doc
module Nested
  # class doc
  class Klass
  end
  
  # mod doc
  module Mod
  end
end

# class NotATask
#   class << self
#     def config(*args)
#     end
#   end
#   
#   config = "is not documented"
# 
#   config :is, :documented
#   
#   config = [:is, :not, :documented]
# end

class TDocTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods

  condition(:irb_variant) { env('tdoc_with_irb') }
  if satisfied?(:irb_variant)
    require 'irb'
  end
    
  require 'tap/support/tdoc'
  include Tap::Support
    
  TDoc.document(__FILE__)
  
   #
   # RDoc RubyLex and RubyToken redefinition test
   #
   
   def test_rubylex_and_rubytoken_redefinition   
     filepath = __FILE__  
     tl = RDoc::TopLevel.new(filepath)
     stats = RDoc::Stats.new
     options = Options.instance
     parser = RDoc::RubyParser.new(tl, filepath, File.read(filepath), options, stats)
     
     assert Tap::Support::TDoc::ConfigParser.included_modules.include?(RDoc::RubyToken)
     assert RDoc::RubyParser.included_modules.include?(RDoc::RubyToken)
     assert_equal RDoc::RubyLex, parser.instance_variable_get("@scanner").class
     
     if satisfied?(:irb_variant)
       assert_not_equal RubyToken, RDoc::RubyToken
       assert_not_equal RubyLex, RDoc::RubyLex
       assert RubyLex.included_modules.include?(RubyToken)
       assert !RubyLex.included_modules.include?(RDoc::RubyLex)
     else
       flunk unless !Object.const_defined?(:RubyToken) || RubyToken == RDoc::RubyToken
       flunk unless !Object.const_defined?(:RubyLex) || RubyLex == RDoc::RubyLex
     end
   end
  
   #
   # [] tests
   #
   
   def test_get_class_documentation
     c = TDoc[TaskDocumentation]
     assert_equal RDoc::NormalClass, c.class
     assert_equal "# = Section One\n# section one\n#\n# == Section Two\n# section two\n# line two\n", c.comment
     
     
     c = TDoc[Nested]
     assert_equal RDoc::NormalModule, c.class
     assert_equal "# nested doc\n", c.comment
     
     c = TDoc[Nested::Klass]
     assert_equal RDoc::NormalClass, c.class
     assert_equal "# class doc\n", c.comment
     
     c = TDoc[Nested::Mod]
     assert_equal RDoc::NormalModule, c.class
     assert_equal "# mod doc\n", c.comment
   end
   
   def test_get_documentation_works_for_strings_and_constants
     assert_equal RDoc::NormalClass, TDoc[Nested::Klass].class
     assert_equal TDoc["Nested::Klass"].object_id, TDoc[Nested::Klass].object_id
   end
   
   def test_configs_are_documented
     c = TDoc[TaskDocumentation]
     
     attributes = c.attributes.collect do |attribute|
       case attribute
       when TDoc::ConfigAttr
         {:comment => attribute.original_comment,
         :name => attribute.name,  
         :rw => attribute.rw, 
         :text => attribute.text,
         :default => attribute.default}
       else
         {:comment => attribute.comment,
         :name => attribute.name,  
         :rw => attribute.rw, 
         :text => attribute.text}
       end
     end
     
     expected_attributes.each_with_index do |expected, i|
       assert_equal expected, attributes[i], "unequal attribute (index=#{i})"
     end
     assert_equal expected_attributes.length, attributes.length
   end
   
   #
   # accessor extensions
   #
   
   def test_comment_sections
     c = TDoc[TaskDocumentation]
     
     assert c.respond_to?(:comment_sections)
     assert_equal({
       "Section One" => "# section one\n#\n",
       "Section Two" => "# section two\n# line two\n"},
     c.comment_sections)
     
     assert_equal({
       "Section Two" => "# section two\n# line two\n"},
     c.comment_sections(/two/i))
     
     assert_equal({
       "Section Two" => "section two\nline two"},
     c.comment_sections(/two/i, true))
   end
   
   # def test_collect_configurations
   #   c = TDoc.document(TaskDocumentation, __FILE__)
   #   assert_equal expected_attributes[0..-5], TDoc.collect_configurations(c)
   # end
   # 
   # def test_collect_attributes
   #   c = TDoc.document(TaskDocumentation, __FILE__)
   #   assert_equal expected_attributes[-4..-1], TDoc.collect_attributes(c)
   # end
   
   def expected_attributes 
     @expected_attributes ||= [{
       :comment=>nil,
       :name=>"c_accessor",
       :rw=>"RW",
       :text=>"# c_accessor",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"c_validation",
       :rw=>"RW",
       :text=>"# c_validation",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"c",
       :rw=>"RW",
       :text=>"# c",
       :default => "'value'"},
     {
       :comment=>"# c_conventional\n",
       :name=>"c_conventional",
       :rw=>"RW",
       :text=>"",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"c_without_doc",
       :rw=>"RW",
       :text=>"",
       :default => "'value'"},
     {
       :comment=>"# c_multiline1\n",
       :name=>"c_multiline",
       :rw=>"RW",
       :text=>"# c_multiline2",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"alt_c",
       :rw=>"RW",
       :text=>"# alt_c",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"alt_c_validation",
       :rw=>"RW",
       :text=>"# alt_c_validation",
       :default => "'value'"},
     {
       :comment=>nil,
       :name=>"alt_c_without_value",
       :rw=>"RW",
       :text=>"# alt_c_without_value",
       :default => nil},
     {
       :comment=>nil,
       :name=>"alt_c_validation_without_value",
       :rw=>"RW",
       :text=>"# alt_c_validation_without_value",
       :default => nil},
     {
       :comment=>"# attr_accessor\n",
       :name=>"attr_accessor",
       :rw=>"RW",
       :text=>"# ignored"},
     {
       :comment=>nil,
       :name=>"attr_accessor_without_doc",
       :rw=>"RW",
       :text=>""},
     {
       :comment=>"# multi_attr_accessor\n",
       :name=>"multi_attr_accessor1",
       :rw=>"RW",
       :text=>""},
     {
       :comment=>"# multi_attr_accessor\n",
       :name=>"multi_attr_accessor2",
       :rw=>"RW",
       :text=>""}]
   end
   
   #
   # NotATask documentation
   #
   
   # def test_not_a_task_document
   #   c = TDoc.document(NotATask, __FILE__)
   #   
   #   assert_equal RDoc::NormalClass, c.class
   #   assert_equal "", c.comment
   #   
   #   attributes = c.attributes.collect do |attribute|
   #     case attribute
   #     when TDoc::ConfigAttr
   #     {:comment => attribute.original_comment,
   #     :name => attribute.name,  
   #     :rw => attribute.rw, 
   #     :text => attribute.text}
   #     else
   #       {:comment => attribute.comment,
   #       :name => attribute.name,  
   #       :rw => attribute.rw, 
   #       :text => attribute.text}
   #     end
   #   end
   #   
   #   not_a_task_expected_attributes.each_with_index do |expected, i|
   #     assert_equal expected, attributes[i], "unequal attribute (index=#{i})"
   #   end
   #   assert_equal not_a_task_expected_attributes.length, attributes.length
   # end
   
   # def not_a_task_expected_attributes 
   #   @not_a_task_expected_attributes ||= [{
   #   :comment=>nil,
   #   :name=>"is",
   #   :rw=>"RW",
   #   :text=>""},
   #  {
   #   :comment=>nil,
   #   :name=>"documented",
   #   :rw=>"RW",
   #   :text=>""}]
   # end
end
