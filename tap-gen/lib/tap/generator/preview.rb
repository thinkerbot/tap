require 'stringio'

module Tap
  module Generator
    
    # Preview is a testing module designed so that process will return an array
    # of relative paths for the created files/directories (which are easy
    # to specify in a test).  Preview also collects the content of created files
    # to be tested as needed.
    #
    #   class Sample < Tap::Generator::Base
    #     def manifest(m)
    #       dir = path('dir')
    #
    #       m.directory dir
    #       m.file(File.join(dir, 'file.txt')) {|io| io << "content"}
    #     end
    #   end
    #
    # These assertions will pass:
    #
    #   s = Sample.new.extend Preview
    #   assert_equal %w{
    #     dir
    #     dir/file.txt
    #   }, s.process
    #
    #   assert_equal "content", s.preview['dir/file.txt']
    #
    # Note that relative paths are relative to destination_root.
    module Preview
      
      # A hash of (relative_path, content) pairs representing
      # content built to files.
      attr_accessor :preview
      
      # The action for self (default :preview)
      attr_accessor :action
      
      def self.extended(base) # :nodoc:
        base.instance_variable_set(:@preview, {})
        base.instance_variable_set(:@action, :preview)
      end
      
      # Returns the path of path, relative to destination_root.  If path
      # is destination_root, '.' will be returned.
      def relative_path(path)
        path = Root::Utils.relative_path(destination_root, path, destination_root) || path
        path.empty? ? "." : path
      end
      
      # Returns the relative path of the target.
      def directory(target, options={})
        relative_path(target)
      end
      
      # Returns the relative path of the target.  If a block is given, 
      # the block will be called with a StringIO and the results stored
      # in builds.
      def file(target, options={})
        target = relative_path(target)
        
        if block_given?
          io = StringIO.new
          yield(io)
          preview[target] = io.string
        end
        
        target
      end
    end
  end
end
