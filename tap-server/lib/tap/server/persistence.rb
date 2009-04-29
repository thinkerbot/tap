module Tap
  class Server
    
    # A very simple wrapper for root providing a CRUD interface for reading and
    # writing files.
    class Persistence < Tap::Root
      ID = /\A[0-9]+\z/
      
      def id
        base = File.basename(root)
        if base =~ Persistence::ID
          base.to_i
        else
          nil
        end
      end
      
      # A restricted version of the original.  Path raises an error if the
      # final path is not relative to als.
      def path(als, *paths)
        path = super
        unless relative?(:root, path)
          raise "not relative to root: #{paths.inspect}"
        end
        path
      end
      
      def entry_path(als, id)
        path(als, id.to_s)
      end
      
      # Returns a list of entry paths.
      def entries(als)
        glob(als, "[0-9]*").select do |path|
          File.file?(path) && File.basename(path) =~ ID
        end
      end
      
      # Returns a list of existing ids.
      def index(als)
        entries(als).collect do |path|
          File.basename(path).to_i
        end
      end
      
      # Returns an available integer id, usually the number of entries in self,
      # but a random integer is generated if that number is taken.
      def next_id(als)
        # try the next in the sequence
        id = entries(als).length
        
        # if that already exists, go for a random id
        id = random_key(length) while find(als, id)
        id
      end
      
      # Returns the path for the specified entry, if it exists.  Returns nil
      # if no such entry can be found.
      def find(als, id)
        path = entry_path(als, id)
        File.file?(path) ? path : nil
      end
      
      # Creates an entry (ie a file) for the specified id.  Yields the open
      # file to the block if given, otherwise the file will be created
      # without content.  Returns the path to the file.
      #
      # Raises an error if the file already exists.
      def create(als, id)
        path = entry_path(als, id)
        if File.exists?(path)
          raise "already exists: #{id.inspect} (#{als.inspect})"
        end
        create!(path) {|io| yield(io) if block_given? }
      end
      
      # Reads and returns the data for the specified entry, or nil if
      # the entry doesn't exist.
      def read(als, id)
        path = find(als, id)
        path ? File.read(path) : nil
      end
      
      def open(als, id)
        path = entry_path(als, id)
        create!(path) {|io| yield(io) }
      end
      
      # Overwrites the data for the specified entry.  A block must be given to
      # provide the new content; an error is raised if the entry does not
      # already exist.
      def update(als, id)
        path = entry_path(als, id)
        unless File.exists?(path)
          raise "does not exist: #{id.inspect} (#{als.inspect})"
        end
        create!(path) {|io| yield(io) }
      end
      
      # Removes the specified entry (ie file), if it exists.  Returns true if
      # the file was removed and false otherwise.
      def destroy(als, id)
        if path = find(als, id)
          FileUtils.rm(path)
          true
        else
          false
        end
      end
      
      protected
      
      # helper to optimize the creation of entries when path is already
      # resolved (using the instance prepare requires a second path
      # resolution)
      def create!(path) # :nodoc:
        Tap::Root::Utils.prepare(path) {|io| yield(io) }
      end
      
      # Generates a random integer key.
      def random_key(length) # :nodoc:
        length = 1 if length < 1
        rand(length * 10000).to_s
      end
    end
  end
end