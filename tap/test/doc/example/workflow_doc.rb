require File.join(File.dirname(__FILE__), '../../doc_test_helper')

class WorkflowDoc < Test::Unit::TestCase
  include Doctest
  
  # === Sequence
  #   % tap run -- load 'goodnight moon' --: dump
  #   goodnight moon
  def test_sequence
    cmd = "% tap run -- load 'goodnight moon' --: dump".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight moon\n", sh(cmd)
  end
  
  # === Sequence (canonical)
  #   % tap run -- load 'goodnight moon' -- dump --[0][1]
  #   goodnight moon
  #
  def test_sequence_canonical
    cmd = "% tap run -- load 'goodnight moon' -- dump --[0][1]".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight moon\n", sh(cmd)
  end
  
  # === Fork
  #   % tap run -- load 'goodnight moon' -- dump -- dump --[0][1,2]
  #   goodnight moon
  #   goodnight moon
  def test_fork
    cmd = "% tap run -- load 'goodnight moon' -- dump -- dump --[0][1,2]".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight moon\ngoodnight moon\n", sh(cmd)
  end
  
  # === Merge
  #   % tap run -- load goodnight -- load moon -- dump --[0,1][2]
  #   goodnight
  #   moon
  def test_merge
    cmd = "% tap run -- load goodnight -- load moon -- dump --[0,1][2]".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight\nmoon\n", sh(cmd)
  end
  
  # === Synchronized Merge
  #   % tap run -- load goodnight --load moon -- dump --[0,1][2].sync
  #   goodnightmoon
  def test_syncrhonized_merge
    cmd = "% tap run -- load goodnight -- load moon -- dump --[0,1][2].sync".sub(CMD_PATTERN, CMD)
    assert_equal "goodnightmoon\n", sh(cmd)
  end
  
end