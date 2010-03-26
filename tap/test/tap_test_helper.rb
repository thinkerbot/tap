require 'test/unit'

begin
  require 'lazydoc'
  require 'configurable'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized. Use these commands and try again:
 
% git submodule init
% git submodule update
 
}
  raise
end

module TapTestMethods
  TAP_ROOT = File.expand_path("../..", __FILE__)
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir('.', true)
  end

  def teardown
    Dir.chdir(@pwd)
    super
  end

  def sh_test_options
    {
      :cmd_pattern => "% tap", 
      :cmd => [
        "ruby 2>&1",
        "-I'#{TAP_ROOT}/../configurable/lib'",
        "-I'#{TAP_ROOT}/../lazydoc/lib'",
        "-I'#{TAP_ROOT}/lib'",
        "'#{TAP_ROOT}/bin/tap'"
      ].join(" "),
      :indents => true,
      :env => default_env,
      :replace_env => false
    }
  end

  def default_env
    {
      'HOME' => method_root.path('home'),
      'TAPFILE'  => '',
      'TAP_GEMS' => '', 
      'TAP_PATH' => "#{TAP_ROOT}:.",
      'TAPENV'   => '',
      'TAPRC'    => '',
      'TAP_GEMS' => ''
    }
  end
end unless Object.const_defined?(:TapTestMethods)