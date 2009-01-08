require 'stringio'

module Tap
  module Generator
    
    # Preview is a testing module designed so that process will return an array
    # of relative filepaths for the created files/directories (which are easy
    # to specify in a test).  Preview also collects the content of created files
    # to be tested as needed.
    #
    #   class Sample < Tap::Generator::Base
    #     def manifest(m)
    #       dir = app.filepath(:root, 'dir')
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
    #   builds = s.builds
    #   assert_equal "content", builds['dir/file.txt']
    #
    # Note that relative filepaths are determined from app.root for the
    # instance; in tests like the one above, it may be prudent to reset
    # the Tap::App.instance like so:
    #
    #   def setup
    #     Tap::App.instance = Tap::App.new
    #   end
    #
    module Preview
      
      # A hash of (relative_path, content) pairs representing
      # content built to files.
      attr_accessor :builds
      
      def self.extended(base) # :nodoc:
        base.instance_variable_set(:@builds, {})
      end
      
      # Returns the path of path, relative to app.root.  If path
      # is app.root, '.' will be returned.
      def relative_path(path)
        path = app.relative_filepath(:root, path) || path
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
          builds[target] = io.string
        end
        
        target
      end
    end
  end
end
