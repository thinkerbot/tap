require 'test/unit'
require 'tempfile'

module Doctest
  TAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/..")
  CMD_PATTERN = "% tap"
  CMD = [
    "ruby",
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def setup
    super
    puts method_name if ENV['VERBOSE'] == 'true'
    
    @tap_gems = ENV['TAP_GEMS']
    ENV['TAP_GEMS'] = ''
  end
  
  def teardown
    super
    ENV['TAP_GEMS'] = @tap_gems
  end
  
  def path(path)
    if RUBY_PLATFORM =~ /mswin/
      File.expand_path(path).gsub("/", "\\")
    else
      "'#{File.expand_path(path)}'"
    end
  end
  
  def tempfile
    Tempfile.open(method_name) do |io|
      yield(io, path(io.path))
    end
  end
  
  def sh(cmd)
    IO.popen(cmd) do |io|
      yield(io) if block_given?
      io.read
    end
  end
  
  def sh_test(cmd)
    unless cmd =~ /\A\s#{CMD_PATTERN}(.*?)\n(.+)\z/m
      raise "invalid sh_test command: #{cmd}"
    end
    
    start = Time.now
    result = sh(CMD + $1)
    finish = Time.now
    
    assert_equal $2, result, CMD + $1
    puts "  (#{time(start, finish)}s) #{CMD_PATTERN + $1}" if ENV['VERBOSE'] == 'true'
  end
  
  def sh_match(cmd, *regexps)
    unless cmd =~ /\A#{CMD_PATTERN}(.*?)\z/
      raise "invalid sh_match command: #{cmd}"
    end
    
    start = Time.now
    result = sh(CMD + $1)
    finish = Time.now
    
    regexps.each do |regexp|
      assert_match regexp, result, CMD_PATTERN + $1
    end
    puts "  (#{time(start, finish)}s) #{CMD_PATTERN + $1}" if ENV['VERBOSE'] == 'true'
  end
  
  def time(start, finish)
    "%.3f" % [finish-start]
  end
end unless Object.const_defined?(:Doctest)