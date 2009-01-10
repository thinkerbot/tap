require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/utils'

class NeedOne < Tap::Task
end
class NeedTwo < Tap::Task
end

class DeclarationsTest < Test::Unit::TestCase
  include Rap::Utils
  
  #
  # resolve_args test
  #

  def test_resolve_args
    assert_equal ['name', {}, [], []], resolve_args(['name'])
    assert_equal ['name', {:key => 'value'}, [], [:one, :two]], resolve_args([:name, :one, :two, {:key => 'value'}])
  end
  
  def test_resolve_args_looks_up_needs
    assert_equal ['name', {}, [NeedOne], []], resolve_args([{:name => :need_one}])
    assert_equal ['name', {}, [NeedOne, NeedTwo], []], resolve_args([{:name => [:need_one, :need_two]}])
  end

  def test_resolve_args_yields_to_block_to_lookup_unknown_needs
    assert !Object.const_defined?(:NeedThree)
    
    was_in_block = false
    args = resolve_args([{:name => [:need_three]}]) do |name|
      assert_equal "NeedThree", name
      was_in_block = true
      NeedTwo
    end
    
    assert was_in_block
    assert_equal ['name', {}, [NeedTwo], []], args
  end

  def test_resolve_args_normalizes_names
    assert_equal ['name', {}, [], []], resolve_args([:name])
    assert_equal ['nested/name', {}, [], []], resolve_args(['nested/name'])
    assert_equal ['nested/name', {}, [], []], resolve_args(['nested:name'])
    assert_equal ['nested/name', {}, [], []], resolve_args([:'nested:name'])
  end

  def test_resolve_args_raises_error_if_no_task_name_is_specified
    e = assert_raises(ArgumentError) { resolve_args([]) }
    assert_equal "no task name specified", e.message

    e = assert_raises(ArgumentError) { resolve_args([{}]) }
    assert_equal "no task name specified", e.message
  end

  def test_resolve_args_raises_error_if_multiple_task_names_are_specified
    e = assert_raises(ArgumentError) { resolve_args([{:one => [], :two => []}]) }
    assert e.message =~ /multiple task names specified: \[.*:one.*\]/
    assert e.message =~ /multiple task names specified: \[.*:two.*\]/
  end
  
  def test_nil_needs_are_ignored
    assert_equal ['name', {}, [], []], resolve_args([{:name => [nil, nil, nil]}])
  end
  
  def test_resolve_args_raises_error_needs_cannot_be_resolved
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:need_three]}]) }
    assert_equal "unknown task class: NeedThree", e.message
    
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:need_three]}]) {|name| nil } }
    assert_equal "unknown task class: NeedThree", e.message
  end
  
  def test_resolve_args_raises_error_if_need_is_not_a_task_class
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:object]}]) }
    assert_equal "not a task class: Object", e.message
  end

  #
  # normalize_name test
  #

  def test_normalize_name_documentation
    assert_equal "nested/name", normalize_name('nested:name')
    assert_equal "symbol", normalize_name(:symbol)
  end
end