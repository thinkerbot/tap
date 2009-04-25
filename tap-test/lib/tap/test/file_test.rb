require 'tap/test/file_test/class_methods'
require 'tap/test/utils'

module Tap
  module Test  
    
    # FileTest facilitates access and utilization of test-specific files and
    # directories. FileTest provides each test method with a Tap::Root 
    # (method_root) specific for the method, and defines a new assertion method 
    # (assert_files) to facilitate tests which involve the production and/or 
    # modification of files.
    #
    #   [file_test_doc_test.rb]
    #   class FileTestDocTest < Test::Unit::TestCase
    #     acts_as_file_test
    # 
    #     def test_something
    #       # each test class has a class test root (ctr)
    #       # and each test method has a method-specific
    #       # root (method_root)
    #
    #       ctr.root                        # => File.expand_path(__FILE__.chomp('_test.rb'))
    #       method_root.root                # => File.join(ctr.root, "/test_something")
    #       method_root[:input]             # => File.join(ctr.root, "/test_something/input")
    #
    #       # files in the :output and :tmp directories are cleared
    #       # before and after each test; this passes each time the
    #       # test is run with no additional cleanup:
    #
    #       assert !File.exists?(method_root[:tmp])
    #
    #       tmp_file = method_root.prepare(:tmp, 'sample.txt') {|file| file << "content" }
    #       assert_equal "content", File.read(tmp_file)
    #
    #       # the assert_files method compares files produced
    #       # by the block the expected files, ensuring they
    #       # are the same (see the documentation for the 
    #       # simplest use of assert_files)
    #       
    #       expected_file = method_root.prepare(:expected, 'output.txt') {|file| file << 'expected output' }
    #
    #       # passes
    #       assert_files do 
    #         method_root.prepare(:output, 'output.txt') {|file| file << 'expected output' }
    #       end 
    #     end
    #   end
    #
    # FileTest requires that a method_name method is provided by the including
    # class, in order to properly set the directory for method_root.
    module FileTest
      
      def self.included(base) # :nodoc:
        super
        base.extend FileTest::ClassMethods
        base.cleanup_dirs = [:output, :tmp]
      end
      
      # The test-method-specific Tap::Root which may be used to
      # access test files.  method_root is a duplicate of ctr
      # reconfigured so that method_root.root is ctr[method_name.to_sym]
      attr_reader :method_root
      
      # Sets up method_root and calls cleanup.  Be sure to call super when
      # overriding this method.
      def setup
        super
        @method_root = ctr.dup.reconfigure(:root => ctr[method_name.to_sym])
        cleanup
      end
      
      # Cleans up the method_root.root directory by removing the class
      # cleanup_dirs (by default :tmp and :output). The root directory
      # will also be removed if it is empty.
      # 
      # Override as necessary in subclasses.
      def cleanup
        self.class.cleanup_dirs.each do |dir|
          clear_dir(method_root[dir])
        end
        try_remove_dir(method_root.root)
      end
    
      # Calls cleanup unless flagged otherwise by an ENV variable. To prevent
      # cleanup (when debugging for example), set the 'KEEP_OUTPUTS' or 
      # 'KEEP_FAILURES' ENV variables:
      #
      #   % rap test KEEP_OUTPUTS=true
      #   % rap test KEEP_FAILURES=true
      #
      # Cleanup is only suppressed for failing tests when KEEP_FAILURES is
      # specified.  Be sure to call super when overriding this method.
      def teardown
        # check that method_root still exists (nil may
        # indicate setup was overridden without super)
        unless method_root
          raise "teardown failure: method_root is nil (does setup call super?)"
        end
        
        # clear out the output folder if it exists, unless flagged otherwise
        unless ENV["KEEP_OUTPUTS"] == "true" || (!passed? && ENV["KEEP_FAILURES"] == "true")
          begin
            cleanup
          rescue
            raise("cleanup failure: #{$!.message}")
          end
        end
        
        try_remove_dir(ctr.root)
      end 
      
      # Convenience method to access the class_test_root.
      def ctr
        self.class.class_test_root or raise "setup failure: no class_test_root has been set for #{self.class}"
      end
      
      # Runs a file-based test that compares files created by the block with
      # files in an expected directory.  The block receives files from the
      # input directory, and should return a list of files relative to the 
      # output directory.  Only the files returned by the block are compared;
      # additional files in the output directory are effectively ignored.
      #
      # === Example
      # Lets define a test that transforms input files into output files in a
      # trivial way, simply by replacing 'input' with 'output' in the file.
      #
      #   class FileTestDocTest < Test::Unit::TestCase
      #     acts_as_file_test
      # 
      #     def test_assert_files
      #       assert_files do |input_files|
      #         input_files.collect do |path|
      #           input = File.read(path)
      #           output_file = method_root.path(:output, File.basename(path))
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
      # Now say you had some input and expected files for test_assert_files:
      #
      #   file_test_doc/test_assert_files
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
      # block.  When the block completes, assert_files compares the output
      # files returned by the block with the files in the expected directory.
      # In this case, the files are equal and the test passes.
      #
      # Say you changed the content of one of the expected files:
      #
      #   [expected/one.txt]
      #   test flunk 1
      #
      # Now the test fails because the output files aren't equal to the
      # expected files.  The test also fails if there are missing or extra
      # files. 
      #
      # === Options
      # A variety of options adjust the behavior of assert_files:
      # 
      #   :input_dir                      specify the directory to glob for input files
      #                                     (default method_root[:input])
      #   :output_dir                     specify the output directory
      #                                     (default method_root[:output])
      #   :expected_dir                   specify the directory to glob for expected files
      #                                     (default method_root[:expected])
      #   :input_files                    directly specify the input files for the block
      #   :expected_files                 directly specify the expected files for comparison
      #   :include_input_directories      specifies directories to be included in the 
      #                                     input_files array (by default dirs are excluded)
      #   :include_expected_directories   specifies directories to be included in the
      #                                     expected-output file list comparison 
      #                                     (by default dirs are excluded)  
      #                  
      # assert_files will fail if <tt>:expected_files</tt> was not specified
      # in the options and no files were found in <tt>:expected_dir</tt>.  This
      # check tries to prevent silent false-positive results when you forget to
      # put expected files in their place.
      #
      # === File References
      #
      # Sometimes the same files will get used across multiple tests.  To allow
      # separate management of test files and prevent duplication, file 
      # references can be provided in place of test files.  For instance, with a
      # test directory like:
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
      # The input and expected files (all references in this case) can be
      # dereferenced to the 'ref' paths like so:
      #
      #   assert_files :reference_dir => method_root[:ref] do |input_files|
      #     input_files # => ['method_root/ref/one.txt', 'method_root/ref/two.txt']
      #
      #     input_files.collect do |input_file|
      #       output_file = method_root.path(:output, File.basename(input_file)
      #       FileUtils.cp(input_file, output_file)
      #       output_file
      #     end
      #   end
      #
      # Dereferencing occurs relative to the input_dir/expected_dir
      # configurations; a reference_dir must be specified for dereferencing to
      # occur (see Utils.dereference for more details).
      #
      # === Keeping Outputs
      #
      # By default FileTest cleans up everything under method_root except the
      # input and expected directories. For ease in debugging, ENV variable
      # flags can be specified to prevent cleanup for all tests (KEEP_OUTPUTS)
      # or just tests that fail (KEEP_FAILURES).  These flags can be specified
      # from the command line if you're running the tests with rake or rap:
      #
      #   % rake test keep_outputs=true
      #   % rap test keep_failures=true
      #
      #--
      # TODO:
      # * add debugging information to indicate, for instance,  
      #   when dereferencing is going on.
      def assert_files(options={}, &block) # :yields: input_files
        transform_test(block, options) do |expected_file, output_file|
          unless FileUtils.cmp(expected_file, output_file) 
            flunk "<#{expected_file}> not equal to\n<#{output_file}>"
          end
        end
      end
      
      # The default assert_files options
      def assert_files_options
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
      
      # Yields to the input block for each pair of entries in the input 
      # arrays.  An error is raised if the input arrays do not have equal 
      # numbers of entries.
      def each_pair(a, b, &block) # :yields: entry_a, entry_b,
        each_pair_with_index(a,b) do |entry_a, entry_b, index|
          yield(entry_a, entry_b)
        end
      end

      # Same as each_pair but yields the index of the entries as well.
      def each_pair_with_index(a, b, error_msg=nil, &block) # :yields: entry_a, entry_b, index
        a = [a] unless a.kind_of?(Array)
        b = [b] unless b.kind_of?(Array)
        
        unless a.length == b.length
          raise ArgumentError, (error_msg || "The input arrays must have an equal number of entries.")
        end
        
        0.upto(a.length-1) do |index|
          yield(a[index], b[index], index)
        end
      end
      
      # Attempts to recursively remove the specified method directory and all 
      # files within it.  Raises an error if the removal does not succeed.
      def clear_dir(dir)
        # clear out the folder if it exists
        FileUtils.rm_r(dir) if File.exists?(dir)
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
      
      def transform_test(block, options={}) # :yields: expected_files, output_files
        options = assert_files_options.merge(options)
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
          output_files = [*block.call(input_files)].collect do |output_file| 
            File.expand_path(output_file)
          end.sort
        
          # check that the expected and output paths are the same
          translated_expected_files = expected_files.collect do |expected_file|
            Tap::Root::Utils.translate(expected_file, expected_dir, output_dir)
          end
          assert_equal translated_expected_files, output_files, "Missing, extra, or unexpected output files"
        
          # check that the expected and output file contents are equal
          errors = []
          each_pair(expected_files, output_files) do |expected_file, output_file|
            unless (File.directory?(expected_file) && File.directory?(output_file)) || FileUtils.cmp(expected_file, output_file)
              begin
                yield(expected_file, output_file)
              rescue
                errors << $!
              end
            end
          end
          flunk "File compare failed:\n" + errors.join("\n") unless errors.empty?
        end
      end
      
    end
  end
end