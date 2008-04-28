require 'tap/root'
require 'tap/test/env_vars'
require 'test/unit'
require 'fileutils'
require 'active_support/core_ext/class'

module Test # :nodoc:
  module Unit # :nodoc:
    class TestCase
      class << self
        
        # Causes a TestCase to act as a file test, by instantiating a class Tap::Root 
        # (trs), and including FileMethods.  The root and directories used to 
        # instantiate trs can be specified as options.  By default file_test_root
        # and the directories {:input => 'input', :output => 'output', :expected => 'expected'} 
        # will be used.
        #
        # Note: file_test_root determines a root directory <em>based on the calling file</em>.  
        # Be sure to specify the root directory explicitly if you call acts_as_file_test
        # from a file that is NOT meant to be test file.
        def acts_as_file_test(options={})
          options = {
            :root => file_test_root,
            :directories => {:input => 'input', :output => 'output', :expected => 'expected'}
          }.merge(options)

          directories = options[:directories]
          trs = Tap::Root.new(options[:root], directories)
    
          write_inheritable_attribute(:trs, trs)
          class_inheritable_reader :trs
      
          include Tap::Test::FileMethods
        end
    
        # Infers the test root directory from the calling file.  Ex:
        #   'some_class.rb' => 'some_class'
        #   'some_class_test.rb' => 'some_class'
        def file_test_root
          # the calling file is not the direct caller of +method_root+... this method is 
          # only accessed from within another method call, hence the target caller is caller[1] 
          # rather than caller[0].
      
          # caller[1] is considered the calling file (which should be the test case)
          # note that the output of calller.first is like:
          #   ./path/to/file.rb:10
          #   ./path/to/file.rb:10:in 'method'
          calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
          calling_file.chomp!("#{File.extname(calling_file)}") 
          calling_file.chomp("_test") 
        end
      end
    end
  end
end

module Tap
  module Test  
    
    # == Overview
    #
    # FileMethods sets up a TestCase with methods for accessing and utilizing
    # test-specific files and directories.  Each class that acts_as_file_test
    # is set up with a Tap::Root structure (trs) that mediates the creation of 
    # test method filepaths. 
    #
    #   class FileMethodsDocTest < Test::Unit::TestCase
    #     acts_as_file_test
    # 
    #     def test_something
    #                           #    dir = File.expand_path( File.dirname(__FILE__) )
    #       trs.root            # => dir + "/file_methods_doc", 
    #       method_root         # => dir + "/file_methods_doc/test_something", 
    #       method_dir(:input)  # => dir + "/file_methods_doc/test_something/input"
    #     end
    #   end
    #
    # === assert_files
    #
    # FileMethods is specifically designed for tests that transform a set of input 
    # files into output files.  For this type of test, input and expected files can
    # placed into their respective directories then used within the context of
    # assert_files to ensure the output files are equal to the expected files.
    # 
    # For example, lets define a test that transforms input files into output files
    # in a trivial way, simply by replacing 'input' with 'output' in the file.
    #
    #   class FileMethodsDocTest < Test::Unit::TestCase
    #     acts_as_file_test
    # 
    #     def test_sub
    #       assert_files do |input_files|
    #         input_files.collect do |filepath|
    #           input = File.read(filepath)
    #           output_file = method_filepath(:output, File.basename(filepath))
    #
    #           File.open(output_file, "w") do |f|
    #             f << input.gsub(/input/, "output")
    #           end 
    #
    #           output_file
    #         end
    #       end
    #     end
    #   end
    #
    # Now say you had some input and expected files for the 'test_sub' method:
    #
    #   [file_methods_doc/test_sub/input/one.txt]
    #   test input 1
    #
    #   [file_methods_doc/test_sub/input/two.txt]
    #   test input 2
    #
    #   [file_methods_doc/test_sub/expected/one.txt]
    #   test output 1
    #
    #   [file_methods_doc/test_sub/expected/two.txt]
    #   test output 2
    #
    # When you run the FileMethodsDocTest test, the test_sub test will pass
    # the input files to the assert_files block.  Then assert_files compares
    # the returned filepaths with the expected files translated from the 
    # expected directory to the output directory.  In this case, the files 
    # are equal and the test passes.
    #
    # The test fails if the returned files aren't equal to the expected files,
    # either because there are missing or extra files, or if the file contents
    # are different. 
    #
    # When the test completes, the teardown method cleans up the output directory.  
    # For ease in debugging, ENV variable flags can be specified to keep all 
    # output files (KEEP_OUTPUTS) or to keep the output files for just the tests 
    # that fail (KEEP_FAILURES).  These flags can be specified from the command 
    # line if you're running the tests with rake or tap:
    #
    #   % rake test keep_outputs=true
    #   % tap run test keep_failures=true
    #
    module FileMethods
      include Tap::Test::EnvVars
  
      # Convenience accessor for the test root structure
      def trs
        self.class.trs
      end
    
      # Creates the trs.directories, specific to the method calling make_test_directories
      def make_test_directories
        trs.directories.values.each do |dir| 
          FileUtils.mkdir_p( File.join(trs.root, method_name_str, dir) )
        end
      end
      
      # Setup deletes the the output directory if it exists, and tries to remove the
      # method root directory so the directory structure is reset before running the
      # test, even if outputs were left over from previous tests.
      def setup
        super
        clear_method_dir(:output)
        try_remove_dir(method_root)
      end
    
      # Teardown deletes the the output directories unless flagged otherwise.  Note 
      # that teardown also checks the environment variables for flags.  To keep all outputs 
      # (or failures) for all tests, flag keep outputs from the command line like:
      #
      #   % tap run test KEEP_OUTPUTS=true
      #   % tap run test KEEP_FAILURES=true
      def teardown     
        # clear out the output folder if it exists, unless flagged otherwise
        unless env("KEEP_OUTPUTS") || (!@test_passed && env("KEEP_FAILURES"))
          begin
             clear_method_dir(:output) 
          rescue
            raise("teardown failure: could not remove output files")
          end
        end
        
        try_remove_dir(method_root)
        try_remove_dir(trs.root)
      end 
      
      # Returns method_name as a string (Ruby 1.9 symbolizes method_name)
      def method_name_str
        method_name.to_s
      end

      # The method_root directory is defined as trs.filepath(method_name)
      def method_root(method=method_name_str)
        trs.filepath(method)
      end

      # The method directory is defined as 'dir/method', where method is the calling method
      # by default.  method_dir returns the method directory if it exists, otherwise it returns
      # trs[dir].
      def method_dir(dir, method=method_name_str)
        File.join(method_root(method), trs.directories[dir] || dir.to_s)
      end
    
      # Returns a glob of files matching the input pattern, underneath the method directory
      # if it exists, otherwise the <tt>trs[dir]</tt> directory.
      def method_glob(dir, *patterns)
        dir = trs.relative_filepath(:root, method_dir(dir))
        trs.glob(dir, *patterns) 
      end
    
      # Returns a filepath constructed from the method directory if it exists, 
      # otherwise the filepath will be constructed from <tt>trs[dir]</tt>. 
      def method_filepath(dir, *filenames)
        File.join(method_dir(dir), *filenames)
      end
    
      # Removes the method directory from the input filepath, returning the resuting filename.
      # If the method directory does not exist, <tt>trs[dir]</tt> will be removed.
      def method_relative_filepath(dir, filepath)
        dir = trs.relative_filepath(:root, method_dir(dir))
        trs.relative_filepath(dir, filepath)
      end
    
      # Returns an output file corresponding to the input file, translated from the
      # input directory to the output directory.  
      #
      # If the input method directory exists, it will be removed from the filepath.  
      # If the output method directory exists, it will be inserted in the filepath.  
      def method_translate(filepath, input_dir, output_dir)
        input_dir = trs.relative_filepath(:root, method_dir(input_dir))
        output_dir = trs.relative_filepath(:root, method_dir(output_dir))
        trs.translate(filepath, input_dir, output_dir)
      end
      
      # Attempts to recursively remove the specified method directory and all 
      # files within it.  Raises an error if the removal does not succeed.
      def clear_method_dir(dir)
        # clear out the folder if it exists
        dir_path = method_dir(dir, method_name_str)
        FileUtils.rm_r(dir_path) if File.exists?(dir_path)
      end
      
      # Attempts to remove the specified directory.  The root 
      # will not be removed if the directory does not exist, or
      # is not empty.  
      def try_remove_dir(dir)
        # Remove the directory if possible
        begin
          FileUtils.rmdir(dir) if File.exists?(dir) && Dir.glob(File.join(dir, "*")).empty?
        rescue
          # rescue cases where there is a hidden file, for example .svn
        end
      end
    
      # Generates a temporary filepath formatted like "output_dir\filename.pid.n.ext" where n 
      # is a counter that will be incremented from until a non-existant filepath is achieved.
      #
      # Notes:
      # - By default filename is the calling method
      # - The extension is chomped off the end of the filename
      # - If the directory for the filepath does not exist, the directory will be created
      # - Like all files in the output directory, tempfiles will be deleted by the default 
      #   +teardown+ method
      def output_tempfile(filename=method_name_str)
        n = 0
        ext = File.extname(filename)
        basename = filename.chomp(ext)
        filepath = make_tmpname(basename, n, ext)
        while File.exists?(filepath)
          n += 1
          filepath = make_tmpname(basename, n, ext)
        end
      
        dirname = File.dirname(filepath)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        filepath
      end

      # Yields to the input block for each pair of entries in the input 
      # arrays.  An error is raised if the input arrays do not have equal 
      # numbers of entries.
      def each_pair(a, b, &block) # :yields: entry_a, entry_b,
        each_pair_with_index(a,b) do |entry_a, entry_b, index|
          yield(entry_a, entry_b)
        end
      end
      
      # Same as each_pair but yields the index of the entries as well.
      def each_pair_with_index(a, b, &block) # :yields: entry_a, entry_b, index
        a = [a] unless a.kind_of?(Array)
        b = [b] unless b.kind_of?(Array)
      
        raise ArgumentError, "The input arrays must have an equal number of entries." unless a.length == b.length
        0.upto(a.length-1) do |index|
          yield(a[index], b[index], index)
        end
      end
      
      # assert_files runs a file-based test that feeds all files in method_dir(:input) 
      # to the block, then compares the resulting files (which should be relative to 
      # method_dir(:output)) with all the files in method_dir(:expected).  Note that
      # since only the files returned by the block are used in the comparison,
      # additional files in the output directory are effectively ignored.
      #
      # A variety of options can be specified to adjust the behavior:
      # 
      #   :input_files                    specify the input files to pass to the block
      #   :expected_files                 specify the expected files used in comparison
      #   :include_input_directories      specifies directories to be included in the 
      #                                     input_files array (by default dirs are excluded)
      #   :include_expected_directories   specifies directories to be included in the
      #                                     expected-output file list comparison (by default 
      #                                     dirs are excluded, note that naturally only files 
      #                                     have their actual content compared)  
      #                  
      # Option keys should be symbols.  assert_files will fail if :expected_files was 
      # not specified in the options and no files were found in method_dir(:expected).  
      # This tries to prevent silent false-positive results when you forget to put 
      # expected files in their place.
      def assert_files(options={}) # :yields: input_files
        make_test_directories
        
        options = {
          :input_files => nil,
          :expected_files => nil,

          :include_input_directories => false,
          :include_expected_directories => false
        }.merge(options)
        
        # Get the input and expected files in this manner:
        # - look for manually specified files
        # - glob for files if none were specified
        # - expand paths and sort
        # - remove directories unless specified not to do so
        input_files, expected_files = [:input, :expected].collect do |key|
          files = options["#{key}_files".to_sym]
          files = method_glob(key) if files.nil?
          files = [files].flatten.collect {|file| File.expand_path(file) }.sort

          unless options["include_#{key}_directories".to_sym]
            files.delete_if {|file| File.directory?(file)} 
          end
          
          files
        end
        
        # check at least one expected file was found
        if expected_files.empty? && options[:expected_files] == nil
          flunk "No expected files specified."
        end
  
        # get output files from the block, expand and sort
        output_files = [yield(input_files)].flatten.collect do |output_file| 
          output_file = File.expand_path(output_file)
        end.sort
        
        # check that the expected and output filepaths are the same
        translated_expected_files = expected_files.collect do |expected_file|
          method_translate(expected_file, :expected, :output)
        end
        assert_equal translated_expected_files, output_files, "Missing, extra, or unexpected output files"

        # check that the expected and output file contents are equal
        errors = []
        each_pair(expected_files, output_files) do |expected_file, output_file|
          unless (File.directory?(expected_file) && File.directory?(output_file)) || FileUtils.cmp(expected_file, output_file)
            errors << "<#{expected_file}> not equal to\n<#{output_file}>"
          end
        end
        flunk "File compare failed:\n" + errors.join("\n") unless errors.empty?
      end

      private
    
      def make_tmpname(basename, n, ext="") # :nodoc:
        method_filepath(:output, sprintf('%s%d.%d%s', basename, $$, n, ext))
      end
    end
  end
end