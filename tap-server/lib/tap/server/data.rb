module Tap
  class Server
    
    # A very simple wrapper for root providing a CRUD interface for reading and
    # writing files.  Data ids may be integers (if you want to pretend Data is
    # a database), or they can be relative paths.
    class Data < Tap::Root
      
      def initialize(config_or_dir=Dir.pwd)
        if config_or_dir.kind_of?(Tap::Root)
          config_or_dir = config_or_dir.config.to_hash
        end
        
        super(config_or_dir)
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
        id = id.to_s
        raise "no id specified" if id.empty?
        path(als, id)
      end
      
      # Returns a list of entry paths.
      def entries(als)
        glob(als).select do |path|
          File.file?(path)
        end
      end
      
      # Returns a list of existing ids.
      def index(als)
        entries(als).collect do |path|
          relative_path(als, path)
        end
      end
      
      # Returns an available integer id, usually the number of entries in self,
      # but a random integer is generated if that number is taken.
      def next_id(als)
        # try the next in the sequence
        id = entries(als).length
        
        # if that already exists, go for a random id
        while find(als, id)
          id = rand(id * 10000)
        end
        
        id
      end
      
      # Returns the path for the specified entry, if it exists.  Returns nil
      # if no such entry can be found.
      def find(als, id)
        return nil unless id
        
        path = entry_path(als, id)
        File.file?(path) ? path : nil
      end
      
      # Creates an entry (ie a file) for the specified id.  Yields the open
      # file to the block if given, otherwise the file will be created
      # without content.  Returns the path to the file.
      #
      # Raises an error if the file already exists.
      def create(als, id)
        path = non_existant_path(als, id)
        create!(path) {|io| yield(io) if block_given? }
      end
      
      # Reads and returns the data for the specified entry, or nil if
      # the entry doesn't exist.
      def read(als, id)
        path = find(als, id)
        path ? File.read(path) : nil
      end
      
      # Overwrites the data for the specified entry.  A block must be given to
      # provide the new content; an error is raised if the entry does not
      # already exist.
      def update(als, id)
        path = existing_path(als, id)
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
      
      def open(als, id)
        path = entry_path(als, id)
        create!(path) {|io| yield(io) }
      end
      
      def import(als, upload, id=nil)
        path = non_existant_path(als, id || upload[:filename])
        
        prepare(path)
        FileUtils.mv(upload[:tempfile].path, path)
        path
      end
      
      def move(als, id, new_id)
        path = existing_path(als, id)
        new_path = non_existant_path(als, new_id)
        
        prepare(new_path)
        FileUtils.mv(path, new_path)
        new_path
      end
      
      def copy(als, id, new_id)
        path = existing_path(als, id)
        new_path = non_existant_path(als, new_id)
        
        prepare(new_path)
        FileUtils.copy(path, new_path)
        new_path
      end
      
      protected
      
      # helper to optimize the creation of entries when path is already
      # resolved (using the instance prepare requires a second path
      # resolution)
      def create!(path) # :nodoc:
        Utils.prepare(path) {|io| yield(io) }
      end
      
      # like find but raises an error if the path doesn't exist
      def existing_path(als, id)
        path = entry_path(als, id)
        unless File.exists?(path)
          raise "does not exist: #{id.inspect} (#{als.inspect})"
        end
        path
      end
      
      # like find but raises an error if the path exists
      def non_existant_path(als, id) # :nodoc:
        path = entry_path(als, id)
        if File.exists?(path)
          raise "already exists: #{id.inspect} (#{als.inspect})"
        end
        path
      end

    end
  end
end