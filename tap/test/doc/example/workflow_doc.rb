require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test'

class WorkflowDoc < Test::Unit::TestCase
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  # === Sequence
  #   % tap run -- load 'goodnight moon' --: dump
  #   goodnight moon
  def test_sequence
    sh_test %Q{
% tap run -- load 'goodnight moon' --: dump
goodnight moon
}
  end
  
  # === Sequence (canonical)
  #   % tap run -- load 'goodnight moon' -- dump --[0][1]
  #   goodnight moon
  #
  def test_sequence_canonical
    sh_test %Q{
% tap run -- load 'goodnight moon' -- dump --[0][1]
goodnight moon
}
  end
  
  # === Fork
  #   % tap run -- load 'goodnight moon' -- dump -- dump --[0][1,2]
  #   goodnight moon
  #   goodnight moon
  def test_fork
    sh_test %Q{
% tap run -- load 'goodnight moon' -- dump -- dump --[0][1,2]
goodnight moon
goodnight moon
}
  end
  
  # === Merge
  #   % tap run -- load goodnight -- load moon -- dump --[0,1][2]
  #   goodnight
  #   moon
  def test_merge
    sh_test %Q{
% tap run -- load goodnight -- load moon -- dump --[0,1][2]
goodnight
moon
}
  end
  
  # === Synchronized Merge
  #   % tap run -- load goodnight --load moon -- dump --[0,1][2].sync
  #   goodnightmoon
  def test_syncrhonized_merge
    sh_test %Q{
% tap run -- load goodnight -- load moon -- dump --[0,1][2].sync
goodnightmoon
}
  end
end