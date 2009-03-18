module Tap
  module Support
    
    # A very simple wrapper for root providing a CRUD interface for reading and
    # writing files.
    class Persistence
      
      # The Tap::Root for self.
      attr_reader :root
      
      # Initializes a new persistence wrapper for the specified root.
      def initialize(root)
        @root = root
      end
      
      # Returns the filepath for the specified id.  Non-string ids are allowed;
      # they will be converted to strings using to_s.
      def path(id)
        root.subpath(:data, id.to_s)
      end
      
      # Returns a list of existing ids.
      def index
        root.glob(:data).select do |path|
          File.file?(path)
        end.collect do |path|
          root.relative_filepath(:data, path)
        end
      end
      
      # Creates the file for the specified id.  If a block is given, an io to
      # the file will be yielded to it; otherwise the file will be created
      # without content.  Returns the path to the persistence file.
      #
      # Raises an error if the file already exists.
      def create(id)
        filepath = path(id)
        raise "already exists: #{filepath}" if File.exists?(filepath)
        root.prepare(filepath) {|io| yield(io) if block_given? }
      end
      
      # Reads and returns the data for the specified id, or an empty string if
      # the persistence file doesn't exist.
      def read(id)
        filepath = path(id)
        File.file?(filepath) ? File.read(filepath) : ''
      end
      
      # Overwrites the data for the specified id.  A block must be given to
      # provide the new content; a persistence file will be created if one
      # does not exist already.
      def update(id)
        root.prepare(path(id)) {|io| yield(io) }
      end
      
      # Removes the persistence file for id, if it exists.  Returns true if
      # the file was removed.
      def destroy(id)
        filepath = path(id)
        
        if File.file?(filepath)
          FileUtils.rm(filepath)
          true
        else
          false
        end
      end
      
    end
  end
end