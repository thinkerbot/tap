module Tap
  module Support
    
    # A very simple wrapper for root providing a CRUD interface for reading and
    # writing files.
    class Persistence
      
      # The Tap::Root for self.
      attr_reader :root
      
      attr_reader :dir
      
      # Initializes a new persistence wrapper for the specified root.
      def initialize(root, dir=:data)
        @root = root
        @dir = dir
      end
      
      # Returns an available integer id, usually the number of entries in self,
      # but a random integer is generated if that number is taken.
      def next_id
        # try the next in the sequence
        length = root.glob(dir).length
        id = length
        
        # if that already exists, go for a random id
        id = random_key(length) while has?(id) 
        id
      end
      
      # Returns the filepath for the specified id.  Non-string ids are allowed;
      # they will be converted to strings using to_s.  Raises an error if the
      # result is not a subpath of the data directory.
      def path(id)
        path = root.path(dir, id.to_s)
        unless root.relative?(dir, path)
          raise "not relative to data dir: #{id.inspect}"
        end
        path
      end
      
      # Returns a list of existing ids.
      def index
        root.glob(dir).select do |path|
          File.file?(path)
        end.collect do |path|
          root.relative_path(dir, path)
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
      
      # Returns true if a file for the id exists.
      def has?(id)
        File.file?(path(id))
      end
      
      # Reads the specified file if it exists, or creates one for id.
      def read_or_create(id)
        has?(id) ? read(id) : create(id)
      end
      
      protected
      
      # Generates a random integer key.
      def random_key(length) # :nodoc:
        length = 1 if length < 1
        rand(length * 10000).to_s
      end
    end
  end
end