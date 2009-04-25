require 'rap/declarations'

module Rap
  module Tasks
    # ::task a testing task
    # The Rap version of Rake::TestTask, shamelessly adapted from the original.
    # The default test command is:
    #
    #   % ruby -w -Ilib -e 'ARGV.each{|f| load f}' TEST_FILES...
    # 
    # Where the test files are all files matching 'test/**/*_test.rb'.  The options
    # can be used to specify other options, lib paths, globs, filters, and even
    # multiple interpreters.
    #
    class Test < DeclarationTask
      include Utils
    
      # The command to launch a ruby interpreter.  Multiple
      # commands many be specified for multiple interpreters.
      # Add ENV variables beforehand like:
      #
      #   cmd "VAR=value ruby"
      #
      config :cmd, ["ruby"], &c.list                     # cmd to launch a ruby interpreter
    
      # Array of options to pass to each cmd.
      config :opts, ["w"], &c.list                       # options to the ruby interpreter
    
      # List of directories to added to $LOAD_PATH before 
      # running the tests.
      config :lib, ['lib'], :short => :I, &c.list        # specify the test libraries
    
      # Note that the default pattern reflects modern
      # test naming conventions.
      config :glob, ["test/**/*_test.rb"], &c.list       # globs to auto-discover test files
    
      # Filters test files, useful for only testing
      # a subset of all tests.  Test files are always
      # filtered, even when manually specified.
      config :filter, ".", &c.regexp                     # a regexp filter of test files
    
      # Iterates over test files to launch them one by one.
      config :iterate, false, &c.switch                  # iteratively runs test files
    
      # Code to load the test files, by default a simple one-liner:
      #
      #   -e 'ARGV.each{|f| load f}'
      #
      def load_code
        "-e 'ARGV.each{|f| load f}'"
      end
    
      def sh(cmd)
        log cmd
        super
      end
    
      def process(*args)
        super
      
        # construct the command options
        options = [load_code]
        opts.each {|opt| options << (opt[0] == ?- ? opt : "-#{opt}") }
        lib.each {|path| options << "-I\"#{File.expand_path(path)}\"" }
        options = options.join(" ")
      
        # select test files
        files = glob.collect do |pattern|
          Dir.glob(pattern).select do |path|
            File.file?(path) && path =~ filter
          end
        end.flatten!
      
        if files.empty?
          log "no files found for: #{glob.inspect}"
        end
      
        files.collect! {|path| "\"#{path}\""}
        files = [files.join(' ')] unless iterate
      
        # launch each test
        files.each do |path|
          cmd.each do |command|
            sh "#{command} #{options} #{path}"
          end
        end
      
        nil
      end
    end
  end
end