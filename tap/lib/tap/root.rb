autoload(:FileUtils, 'fileutils')

module Tap
  class Root
    class << self
      # The path root type indicating windows, *nix, or some unknown style of
      # paths (:win, :nix, :unknown).
      def type
        @path_root_type ||= begin
          pwd = File.expand_path('.')
          
          case
          when pwd =~ WIN_ROOT_PATTERN then :win 
          when pwd[0] == ?/ then :nix
          else :unknown
          end
        end
      end
      
      # Trivial indicates when a path does not have content to load.  Returns
      # true if the file at path is empty, non-existant, a directory, or nil.
      def trivial?(path)
        path == nil || !File.file?(path) || File.size(path) == 0
      end
    
      # Empty returns true when dir is an existing directory that has no files.
      def empty?(dir)
        File.directory?(dir) && (Dir.entries(dir) - ['.', '..']).empty?
      end
    end
    
    # Regexp to match a windows-style root path.
    WIN_ROOT_PATTERN = /\A[A-z]:\//
    
    def initialize(path=Dir.pwd, dir=Dir.pwd)
      @path_root = File.expand_path(path.to_s, dir.to_s)
    end
    
    # Stringifies and expands the path relative to self.  Paths are turned
    # into strings using to_s.
    def expand(path)
      File.expand_path(path.to_s, @path_root)
    end
    
    # Joins and expands the path segments relative to self.  Segments are
    # turned to strings using to_s.
    def path(*segments)
      segments.collect! {|seg| seg.to_s }
      expand(File.join(*segments))
    end
    
    # Returns true if the expanded path is relative to self.
    def relative?(path)
      expand(path).rindex(@path_root, 0) == 0
    end
  
    # Returns the part of the expanded path relative to self, or nil if the
    # path is not relative to self.
    def relative_path(path)
      path = expand(path)
      return nil unless relative?(path)
  
      # if path_root_length > path.length then the first arg
      # returns nil, and an empty string is returned
      path[path_root_length, path.length - path_root_length] || ""
    end
    alias rp relative_path
  
    # Returns a new Root for the path, relative to self.
    def root(path)
      Root.new(path, self)
    end
    
    # Returns a new Root for the path, relative to self.  Same as root but
    # raises an error if the path is not relative to self.
    def sub(path)
      sub = root(path)
      unless relative?(sub)
        raise ArgumentError, "not a sub path: #{sub} (#{self})"
      end
      sub
    end
    
    # Returns a new Root for the parent directory for self.
    def parent
      root File.dirname(@path_root)
    end
  
    # Returns the expanded path, exchanging the extension with extname. 
    # Extname may optionally omit the leading period.
    #
    #   root = Root.new("/root")
    #   root.exchange('path/to/file.txt', '.html')  # => '/root/path/to/file.html'
    #   root.exchange('path/to/file.txt', 'rb')     # => '/root/path/to/file.rb'
    #
    def exchange(path, extname)
      path = expand(path)
      "#{path.chomp(File.extname(path))}#{extname[0] == ?. ? '' : '.'}#{extname}"
    end
    alias ex exchange
    
    # Generates a path translated from the source to the target. Raises an
    # error if path is not relative to the source.
    def translate(path, source, target)
      path = expand(path)
      source = root(source)
      target = root(target)
      
      rp = source.relative_path(path)
      if rp.nil?
        raise ArgumentError, "\n#{path}\nis not relative to:\n#{source}"
      end
      
      target.path(rp)
    end
    alias tr translate
    
    # Globs for unique paths matching the input patterns expanded relative to
    # self. If no patterns are specified, glob returns all paths matching
    # './**/*'.
    def glob(*patterns)
      patterns << "**/*" if patterns.empty?
      patterns.collect! {|pattern| expand(pattern) }
      Dir[*patterns].uniq
    end
    
    # Changes to the specified directory using Dir.chdir, keeping the same
    # block semantics as that method.  The directory will be created if
    # necessary and mkdir is specified.  Raises an error for non-existant
    # directories, as well as non-directory inputs.
    def chdir(dir, mkdir=false, &block)
      dir = expand(dir)
    
      unless File.directory?(dir)
        if !File.exists?(dir) && mkdir
          FileUtils.mkdir_p(dir)
        else
          raise ArgumentError, "not a directory: #{dir}"
        end
      end
    
      Dir.chdir(dir, &block)
    end
    
    # Makes the specified directory and parent directories (as required).
    def mkdir(*path)
      path = self.path(*path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
      path
    end
    
    # Opens the path in the specified mode, using the same semantics as
    # File.open.
    def open(path, mode='r', &block)
      path = expand(path)
      File.open(path, mode, &block)
    end
    
    # Prepares a file at the path by making paths's parent directory. The file
    # is opened in the mode and passed to the block, if given. The mode is
    # ignored if no block is given.
    #
    # Returns path.
    def prepare(*path)
      path = self.path(*path)
      dirname = File.dirname(path)
      FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
      File.open(path, 'w') {|io| yield(io) } if block_given?
      path
    end
    
    # Returns path.
    def to_s
      @path_root
    end
    
    private
    
    # helper to memoize and return the length of path root, plus a trailing
    # separator; used in determining relative paths
    def path_root_length # :nodoc:
      @path_root_length ||= begin
        length = @path_root.length
        unless @path_root == File::SEPARATOR
          length += File::SEPARATOR.length
        end
        length
      end
    end
  end
end