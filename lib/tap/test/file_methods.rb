require 'tap/test/utils'
require 'tap/test/env_vars'
require 'tap/test/file_methods_class'

module Tap
  module Test  
    

    # FileMethods facilitates access and utilization of test-specific files and
    # directories.  Each test method is setup with a method_root (a Tap::Root)
    # specific for the test; the method_root is a duplicate of the class 
    # test_root, reconfigured with method_root.root = test_root[method_name].
    # The acts_as_file_test sets up test_root to point at a directory based
    # on the test file.
    #
    #   [file_methods_doc_test.rb]
    #   class FileMethodsDocTest < Test::Unit::TestCase
    #     acts_as_file_test
    # 
    #     def test_something
    #       self.class.test_root.root     # => File.expand_path(__FILE__.chomp('_test.rb'))
    #       method_root.root              # => File.expand_path(__FILE__.chomp('_test.rb') + "/test_something")
    #       method_root[:input]           # => File.expand_path(__FILE__.chomp('_test.rb') + "/test_something/input")
    #     end
    #   end
    #
    # See {Test::Unit::TestCase}[link:classes/Test/Unit/TestCase.html] and
    # FileMethodsClass for more information.
    module FileMethods
      include Tap::Test::EnvVars
      
      def self.included(base)
        super
        base.extend FileMethodsClass
      end
      
      # Convenience method to access the class test_root.
      def ctr
        self.class.test_root
      end
      
      # Creates the method_root.directories.
      def make_test_directories
        method_root.directories.values.each do |dir| 
          FileUtils.mkdir_p( method_root[dir] )
        end
      end
      
      attr_reader :method_tempfiles
      
      attr_reader :method_root
      
      # Sets up the method_root as a duplicate of test_root, reconfigured to 
      # class.test_root[method_name_str].  Also deletes the the method_root[:output]
      # directory in the event that it was left over from a previous tests.
      def setup
        super
        @method_root = ctr.dup.reconfigure(:root => ctr[method_name_str])
        @method_tempfiles = []
        
        Utils.clear_dir(method_root[:output])
        Utils.try_remove_dir(method_root.root)
      end
    
      # teardown deletes the the method_root[:output] directory unless flagged
      # otherwise by an ENV variable. To keep all outputs (or failures) for all 
      # tests, set the ENV variables from the command line like:
      #
      #   % rap test KEEP_OUTPUTS=true
      #   % rap test KEEP_FAILURES=true
      #
      def teardown     
        # clear out the output folder if it exists, unless flagged otherwise
        unless env("KEEP_OUTPUTS") || (!@test_passed && env("KEEP_FAILURES"))
          begin
             Utils.clear_dir(method_root[:output])
          rescue
            raise("teardown failure: could not remove output files")
          end
        end
        
        Utils.try_remove_dir(method_root.root)
        Utils.try_remove_dir(self.class.test_root.root)
      end 
      
      # Returns method_name as a string (Ruby 1.9 symbolizes method_name)
      def method_name_str
        method_name.to_s
      end
    
      # Generates a temporary filepath formatted like "output_dir\filename.n.ext"
      # where n is a counter that ensures the filepath is unique and non-existant
      # (specificaly n is equal to the number of method_tempfiles generated 
      # by the current test, incremented as necessary to achieve a non-existant
      # filepath). method_tempfile does not create the filepath unless a block is 
      # given, in which case an open File will be passed to the block.
      #
      # Notes:
      # - by default filename is the calling method
      # - the extension is chomped off the end of the filename
      # - the directory for the file will be created if it does not exist
      # - like all files in the output directory, tempfiles will be deleted by
      #   the default +teardown+ method
      def method_tempfile(filename=method_name_str, &block)
        ext = File.extname(filename)
        basename = filename.chomp(ext)
        path = next_indexed_path(method_root.filepath(:output, basename), method_tempfiles.length, ext)
        dirname = File.dirname(path)
        
        method_tempfiles << path
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        File.open(path, "w", &block) if block_given?
        path
      end
      
      # assert_files runs a file-based test that feeds all files from input_dir
      # to the block, then compares the resulting files (which should be relative to 
      # output_dir) with all the files in expected_dir.  Only the files returned by 
      # the block are used in the comparison; additional files in the output directory 
      # are effectively ignored.
      #
      # === Example
      # Lets define a test that transforms input files into output files in a trivial 
      # way, simply by replacing 'input' with 'output' in the file.
      #
      #   class FileMethodsDocTest < Test::Unit::TestCase
      #     acts_as_file_test
      # 
      #     def test_sub
      #       assert_files do |input_files|
      #         input_files.collect do |filepath|
      #           input = File.read(filepath)
      #           output_file = method_root.filepath(:output, File.basename(filepath))
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
      #   file_methods_doc/test_sub
      #   |- expected
      #   |   |- one.txt
      #   |   `- two.txt
      #   `- input
      #       |- one.txt
      #       `- two.txt
      # 
      #   [input/one.txt]
      #   test input 1
      #
      #   [input/two.txt]
      #   test input 2
      #
      #   [expected/one.txt]
      #   test output 1
      #
      #   [expected/two.txt]
      #   test output 2
      #
      # When you run the test, the assert_files passes the input files to the 
      # block.  When the block completes, assert_files compares the output files
      # returned by the block with the files in the expected directory.  In this 
      # case, the files are equal and the test passes.
      #
      # Say you changed the content of one of the expected files:
      #
      #   [expected/one.txt]
      #   test flunk 1
      #
      # Now the test fails because the output files aren't equal to the expected
      # files.  The test will also fail if there are missing or extra files. 
      #
      # === Options
      # A variety of options can be specified to adjust the behavior:
      # 
      #   :input_dir                      specify the directory to glob for input files
      #                                     (default method_root[:input])
      #   :output_dir                     specify the output directory
      #                                     (default method_root[:output])
      #   :expected_dir                   specify the directory to glob for expected files
      #                                     (default method_root[:expected])
      #   :input_files                    directly specify the input files to pass to the block
      #   :expected_files                 directly specify the expected files used for comparison
      #   :include_input_directories      specifies directories to be included in the 
      #                                     input_files array (by default dirs are excluded)
      #   :include_expected_directories   specifies directories to be included in the
      #                                     expected-output file list comparison (by default 
      #                                     dirs are excluded, note that naturally only files 
      #                                     have their actual content compared)  
      #                  
      # assert_files will fail if :expected_files was not specified in the options 
      # and no files were found in :expected_dir.  This check tries to prevent silent
      # false-positive results when you forget to put expected files in their place.
      #
      # === File References
      # Sometimes the same files will get used across multiple tests.  To prevent
      # duplication and allow separate management of test files, file references
      # can be provided in place of test files.  For instance, with a test
      # directory like:
      #
      #   method_root
      #   |- expected
      #   |   |- one.txt.ref
      #   |   `- two.txt.ref
      #   |- input
      #   |   |- one.txt.ref
      #   |   `- two.txt.ref
      #   `- ref
      #       |- one.txt
      #       `- two.txt
      #   
      # The input and expected files (all references in this case) can be dereferenced 
      # to the 'ref' filepaths like so:
      #
      #   assert_files :reference_dir => method_root[:ref] do |input_files|
      #     input_files # => ['method_root/ref/one.txt', 'method_root/ref/two.txt']
      #
      #     input_files.collect do |input_file|
      #       output_file = method_root.filepath(:output, File.basename(input_file)
      #       FileUtils.cp(input_file, output_file)
      #       output_file
      #     end
      #   end
      #
      # Dereferencing occurs relative to the input_dir/expected_dir configurations; a
      # reference_dir must be specified for dereferencing to occur (see 
      # Tap::Test::Utils.dereference for more details).
      #
      # === Keeping Outputs
      # By default FileMethods sets teardown to cleans up the output directory. For 
      # ease in debugging, ENV variable flags can be specified to keep all output 
      # files (KEEP_OUTPUTS) or to keep the output files for just the tests that fail 
      # (KEEP_FAILURES).  These flags can be specified from the command line if you're
      # running the tests with rake or rap:
      #
      #   % rake test keep_outputs=true
      #   % rap test keep_failures=true
      #
      #--
      # TODO:
      # * add debugging information to indicate, for instance,  
      #   when dereferencing is going on.
      def assert_files(options={}) # :yields: input_files
        make_test_directories
        
        options = default_assert_files_options.merge(options)
        input_dir = options[:input_dir]
        output_dir = options[:output_dir] 
        expected_dir = options[:expected_dir]
        
        reference_dir = options[:reference_dir]
        reference_pattern = options[:reference_pattern]
        
        Utils.dereference([input_dir, expected_dir], reference_dir, reference_pattern || '**/*.ref') do

          # Get the input and expected files in this manner:
          # - look for manually specified files
          # - glob for files if none were specified
          # - expand paths and sort
          # - remove directories unless specified not to do so
          input_files, expected_files = [:input, :expected].collect do |key|
            files = options["#{key}_files".to_sym]
            if files.nil?
              pattern = File.join(options["#{key}_dir".to_sym], "**/*")
              files = Dir.glob(pattern)
            end
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
            File.expand_path(output_file)
          end.sort
        
          # check that the expected and output filepaths are the same
          translated_expected_files = expected_files.collect do |expected_file|
            Tap::Root.translate(expected_file, expected_dir, output_dir)
          end
          assert_equal translated_expected_files, output_files, "Missing, extra, or unexpected output files"
        
          # check that the expected and output file contents are equal
          errors = []
          Utils.each_pair(expected_files, output_files) do |expected_file, output_file|
            unless (File.directory?(expected_file) && File.directory?(output_file)) || FileUtils.cmp(expected_file, output_file)
              errors << "<#{expected_file}> not equal to\n<#{output_file}>"
            end
          end
          flunk "File compare failed:\n" + errors.join("\n") unless errors.empty?
        end
      end
      
      # The default assert_files options
      def default_assert_files_options
        {
          :input_dir => method_root[:input],
          :output_dir => method_root[:output],
          :expected_dir => method_root[:expected],
          
          :input_files => nil,
          :expected_files => nil,
          :include_input_directories => false,
          :include_expected_directories => false,
          
          :reference_dir => nil,
          :reference_extname => '.ref'
        }
      end
      
      private
      
      # utility method for method_tempfile; increments index until the
      # path base.indexext does not exist.
      def next_indexed_path(base, index, ext) # :nodoc:
        path = sprintf('%s.%d%s', base, index, ext)
        File.exists?(path) ? next_indexed_path(base, index + 1, ext) : path
      end
    end
  end
end