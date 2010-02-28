require 'tap/test/file_test/class_methods'
require 'tap/test/utils'

module Tap
  module Test  
    
    # FileTest simplifies testing of code that works with files.  FileTest
    # provides a method-specific Tap::Root (method_root) that expedites the
    # creation and access of files, as well as a couple standard cleanup
    # methods.
    #
    # ==== Cleanup
    #
    # By default the entire method_root directory is cleaned up at the end of
    # the test. To prevent cleanup, either set the KEEP_OUTPUTS or
    # KEEP_FAILURES ENV variable to 'true'.  The cleanup directories can be
    # specified manually using cleanup_dirs class variable:
    #
    #   class LimitedCleanupTest < Test::Unit::TestCase
    #
    #     # only cleanup the output directory under root
    #     acts_as_file_test :cleanup_dirs => [:output]
    #   end
    #
    # This technique is useful when you want to keep certain static files
    # under version control, for instance.
    #
    # ==== Requirements
    #
    # FileTest requires that a method_name method is provided by the including
    # class, in order to properly set the directory for root.
    # Test::Unit::TestCase satisfies this requirement already.
    module FileTest
      
      def self.included(base) # :nodoc:
        super
        base.extend FileTest::ClassMethods
      end
      
      # The method-specific Tap::Root
      attr_reader :method_root
      
      # Sets up method_root and calls cleanup.  Be sure to call super when
      # overriding this method.
      def setup
        super
        @method_root = class_root.sub(method_name)
        cleanup
      end
      
      # Cleans up the method_root directory by removing the cleanup_dirs 
      # specified for the class.  (by default the entire method_root directory
      # is removed). The method_root directory will be removed if it is empty.
      #  
      # Override as necessary in subclasses.
      def cleanup
        cleanup_dirs = self.class.cleanup_dirs
        cleanup_dirs.each {|dir| clear_dir(method_root.path(dir)) }
        
        try_remove_dir(method_root.path)
      end
    
      # Calls cleanup unless flagged otherwise by an ENV variable (see above).
      # Be sure to call super when overriding this method.
      def teardown
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
        
        try_remove_dir(class_root.path)
      end 
      
      # Convenience method to access the class_root.
      def class_root
        self.class.class_root or raise "setup failure: no class_root has been set for #{self.class}"
      end
      
      # Attempts to recursively remove the specified method directory and all 
      # files within it.  Raises an error if the removal does not succeed.
      def clear_dir(dir)
        # clear out the folder if it exists
        FileUtils.rm_r(dir) if File.exists?(dir)
      end
      
      # Attempts to remove the specified directory.  The directory will not be
      # removed unless fully empty (including hidden files).
      def try_remove_dir(dir)
        begin
          FileUtils.rmdir(dir) if File.directory?(dir) && Dir.glob(File.join(dir, "*")).empty?
        rescue
          # rescue cases where there is a hidden file, for example .svn
        end
      end
    end
  end
end