require 'tap/test/unit'

# A couple fixture constants...
module ConstName
end

module Nest
  module ConstName
  end
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
        "'#{TAP_ROOT}/bin/tapexe'"
      ].join(" "),
      :indents => true,
      :env => default_env,
      :replace_env => false
    }
  end

  def default_env
    {
      'HOME' => method_root.path('home'),
      'TAPFILE'   => nil,
      'TAP_GEMS'  => nil,
      'TAP_PATH'  => "#{TAP_ROOT}:.",
      'TAPENV'    => nil,
      'TAPRC'     => nil,
      'TAP_GEMS'  => nil,
      'TAP_DEBUG' => nil,
      
      # optimization for jruby:
      # http://blog.headius.com/2010/03/jruby-startup-time-tips.html
      'JAVA_OPTS' => "-d32"
    }
  end
  
  # for some reason jruby gem doesn't want to run itself as ruby, and instead
  # it wants to run as a sh script.  this rigmarole specifically runs it as
  # a ruby script
  #
  #  % gem build tap.gemspec
  #  ...jruby-1.4.0/bin/gem: line 8: require: command not found
  #  ...
  #
  def sh_gem(cmd, options={})
    gem_path = `which gem`.strip
    cmd = cmd.sub(/^gem/, "ruby '#{gem_path}'")
    sh(cmd, options)
  end
  
  def build_gem(name)
    gemspec = "#{TAP_ROOT}/../#{name}/#{name}.gemspec"
    Dir.chdir(File.dirname(gemspec)) do 
      output = sh_gem("gem build #{gemspec} 2>&1")
      flunk("failed to build #{gemspec}: #{output}") unless $? == 0
      
      src = output.split("\n").last.split(": ").last
      target = method_root.prepare('cache', src)
      
      FileUtils.mv(src, target)
      target
    end
  end
  
  def gem_test
    gem_env = default_env.merge(
      'GEM_HOME' => method_root.path('gem'), 
      'GEM_PATH' => method_root.path('gem'),
      'HOME' => method_root.mkdir('home'),
      'TAP_GEMS' => nil
    )
    
    lazydoc = build_gem("lazydoc")
    configurable = build_gem("configurable")
    tap = build_gem("tap")
    sh_gem("gem install '#{lazydoc}' '#{configurable}' '#{tap}' --local --no-rdoc --no-ri", :env => gem_env)
    yield(gem_env)
  end
  
end unless Object.const_defined?(:TapTestMethods)