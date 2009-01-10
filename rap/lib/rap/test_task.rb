require 'rap/declarations'

module Rap
  class TestTask < DeclarationTask
    include Tap::Support::ShellUtils
    
    config :libs, ['lib'], &c.list
    config :pattern, "test/**/*_test.rb", &c.string
    config :options, [], &c.list
    config :verbose, true, &c.switch
    config :warning, true, &c.switch
    config :ruby_opts, [], &c.list
    
    # # Style of test loader to use. Options are:
    # #
    # # * :rake -- Rake provided test loading script (default).
    # # * :direct -- Load tests using command line loader.
    # #
    # config :loader, :direct
    
    config :filter, ".", &c.regexp
    
    def test_files=(list)
      @test_files = list
    end
    
    def run_code
      "-e 'ARGV.each{|f| load f}'"
    end
    
    def test_files
      @test_files ||= Dir.glob(pattern).select {|path| File.file?(path) && path =~ filter }
    end
    
    def process(*args)
      opts = libs.collect {|path| "-I\"#{File.expand_path(path)}\""}
      opts << "-w" if warning
      opts.concat(ruby_opts)
      
      files = test_files.collect {|path| "\"#{path}\""}
      cmd = ["ruby", run_code] + opts + files
      sh(cmd.join(' '))
      
      super
    end
    
  end
end