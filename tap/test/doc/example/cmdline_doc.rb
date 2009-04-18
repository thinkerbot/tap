require 'test/unit'
require 'tempfile'

class CmdlineDoc < Test::Unit::TestCase
  TAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../../../")
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
  
  ######################################
  # IO
  ######################################
  
  # === Read data from $stdin
  #   # [goodnight.txt]
  #   # goodnight moon
  # 
  #   % tap run -- load --: dump < goodnight.txt
  #   goodnight moon
  #
  def test_read_from_stdin
    tempfile do |tmp, path|
      tmp << "goodnight moon"
      tmp.flush
      
      cmd = "% tap run -- load --: dump < #{path}".sub(CMD_PATTERN, CMD)
      assert_equal "goodnight moon", sh(cmd).strip
    end
  end
  
  # === Pipe data from $stdin
  #   % echo goodnight moon | tap run -- load --: dump
  #   goodnight moon
  #
  def test_pipe_from_stdin
    cmd = "echo goodnight moon | #{CMD} run -- load --: dump"
    assert_equal "goodnight moon", sh(cmd).strip
  end
  
  # === Load data from argument
  #   % tap run -- load 'goodnight moon' --: dump
  #   goodnight moon
  #
  def test_load_data_from_argument
    cmd = "% tap run -- load 'goodnight moon' --: dump".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight moon", sh(cmd).strip
  end
  
  # === Dump data to $stdout
  #   % tap run -- load 'goodnight moon' --: dump > goodnight.txt
  #   % more goodnight.txt
  #   goodnight moon
  #
  def test_dump_data_to_stdout
    tempfile do |tmp, path|
      tmp.close
      
      cmd = "% tap run -- load 'goodnight moon' --: dump > #{path}".sub(CMD_PATTERN, CMD)
      assert_equal "", sh(cmd)
      
      cmd = "more #{path}"
      assert_equal "goodnight moon", sh(cmd).strip
    end
  end
  
  # === Pipe data via $stdout
  #   % tap run -- load 'goodnight moon' --: dump | more
  #   goodnight moon
  def test_pipe_data_via_stdout
    cmd = "% tap run -- load 'goodnight moon' --: dump | more".sub(CMD_PATTERN, CMD)
    assert_equal "goodnight moon", sh(cmd).strip
  end
  
  ######################################
  # Workflows
  ######################################
  
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