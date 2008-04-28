# NO idea why this prevents an error with @ruby_opts=nil,
# or even how @ruby_opts could be nil, on ruby 1.9 with
# rake test and tdoc.  It does, though.
require 'pp'

module Rake # :nodoc:

  class TestTask < TaskLib # :nodoc:
    
    # Patch for TestTask#define in 'rake\testtask.rb'
    #
    # This patch lets you specify Windows-style paths in lib 
    # (ie with spaces and slashes) and to do something like:
    #
    #   Rake::TestTask.new(:test) do |t|
    #     t.libs = $:  << 'lib'
    #   end
    #
    # Using this patch you can specify additional load paths 
    # for the test from the command line using --lib-dir
    #
    def define
      lib_opt = @libs.collect {|f| "-I\"#{File.expand_path(f)}\""}.join(' ')
      desc "Run tests" + (@name==:test ? "" : " for #{@name}")
      task @name do
        run_code = ''
        RakeFileUtils.verbose(@verbose) do
          run_code =
            case @loader
            when :direct
              "-e 'ARGV.each{|f| load f}'"
            when :testrb
              "-S testrb #{fix}"
            when :rake
              rake_loader
            end
          @ruby_opts.unshift(lib_opt)
          @ruby_opts.unshift( "-w" ) if @warning
          ruby @ruby_opts.join(" ") +
            " \"#{run_code}\" " +
            file_list.collect { |fn| "\"#{fn}\"" }.join(' ') +
            " #{option_list}"
        end
      end
      self
    end
    
    # Loads in the patched rake_test_loader to avoid the ARGV 
    # modification error, which arises within TDoc.
    def rake_loader # :nodoc:
      File.expand_path(File.join(File.dirname(__FILE__), 'rake_test_loader.rb'))
    end
  end
  
end