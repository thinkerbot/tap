require 'rap/declarations'

module Rap
  
  # The Rap version of Rake::TestTask, shamelessly adapted from the original.
  class TestTask < DeclarationTask
    include Tap::Support::ShellUtils
    
    class << self
      protected
      
      # Defines a depreciated attribute accessor to provide the
      # Rake::TestTask API while warning when a method does nada.
      def depreciated_accessor(name)
        attr_reader name
        define_method("#{name}=") do |*args|
          warn "#{self}.#{name} method is provided for rake compatibility and does nothing"
        end
      end
    end
    
    # List of directories to added to $LOAD_PATH before 
    # running the tests.
    config :libs, ['lib'], &c.list                     # specify the test libraries
    
    depreciated_accessor(:verbose)
    depreciated_accessor(:options)
    
    # Request that the tests be run with the warning
    # flag set. E.g. warning=true implies "ruby -w"
    config :warning, true, &c.switch                   # shortcut to set -w ruby option
    
    # Note that the default pattern reflects more
    # modern testing naming conventions.  The rake
    # default is 'test/test*.rb'
    config :pattern, "test/test*.rb", &c.string        # a glob to auto-discover test files
    
    depreciated_accessor(:loader)
    
    # Array of options to pass to ruby when running
    # test loader.
    config :ruby_opts, [], &c.list                     # options to the ruby interpreter
    
    # Used to manually sepecify test files for the test.
    # If no test files are specified, pattern is globed
    # for test files.  Test files are filtered according
    # to filter, in all cases.
    attr_writer :test_files
    
    # Filters test files, useful for only testing
    # a subset of all tests.  Test files are always
    # filtered, even when manually specified.
    config :filter, ".", &c.regexp                     # a regexp filter of test files
    
    # The command to launch a ruby interpreter.  Multiple
    # commands many be specified for multiple interpreters.
    config :interpreters, ["ruby"], &c.list            # cmd to launch a ruby interpreter
    
    # Iterates over test files to launch them one by one.
    config :iterate, false                             # iteratively runs test files
    
    # The tests files that will be loaded during testing.  These are filtered
    # at test time using filter.  By default test_files are determined by
    # globbing pattern.
    def test_files
      @test_files ||= Dir.glob(pattern)
    end
    
    # Code to load the test files, by default a simple one-liner:
    #
    #   -e 'ARGV.each{|f| load f}'
    #
    def load_code
      "-e 'ARGV.each{|f| load f}'"
    end
    
    def process(*args)
      super
      
      # construct the base command
      opts = libs.collect {|path| "-I\"#{File.expand_path(path)}\""}
      opts << "-w" if warning
      opts.concat(ruby_opts)
      
      base = "#{load_code} #{opts.join(' ')}"
      
      # select test files
      files = test_files.select do |path| 
        File.file?(path) && path =~ filter
      end.collect {|path| "\"#{path}\""}
      
      # construct the commands
      commands = iterate ? files.collect {|file| "#{base} #{file}" } : ["#{base} #{files.join(' ')}"]
      
      # launch each command
      interpreters.each do |interpreter|
        commands.each do |cmd| 
          sh "#{interpreter} #{cmd}"
        end
      end
      
      nil
    end
    
  end
end