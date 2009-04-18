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
end unless Object.const_defined?(:Doctest)