require 'configurable'
require 'tap/root/utils'

module Tap
  
  # Root abstracts a directory to standardize access to resources organized
  # within variable directory structures.
  #
  #   # define a root directory with aliased relative paths
  #   root = Root.new(
  #     :root => '/root_dir', 
  #     :relative_paths => {:input => 'in', :output => 'out'})
  #  
  #   # access aliased paths
  #   root[:input]                                   # => '/root_dir/in'
  #   root[:output]                                  # => '/root_dir/out'
  #   root['implicit']                               # => '/root_dir/implicit'
  #
  #   # absolute paths can also be aliased
  #   root[:abs, true] = "/absolute/path"
  #   root.path(:abs, "to", "file.txt")              # => '/absolute/path/to/file.txt'
  #
  #   # expanded paths are returned unchanged
  #   path = File.expand_path('expanded')
  #   root[path]                                     # => path
  #
  #   # work with paths
  #   path = root.path(:input, 'path/to/file.txt')   # => '/root_dir/in/path/to/file.txt'
  #   root.relative_path(:input, path)               # => 'path/to/file.txt'
  #   root.translate(path, :input, :output)          # => '/root_dir/out/path/to/file.txt'
  #
  # By default, Roots are initialized to the present working directory
  # (Dir.pwd).
  #
  # === Implementation Notes
  #
  # Internally Root expands and stores all aliased paths in the 'paths' hash.
  # Expanding paths ensures they remain constant even when the present working
  # directory (Dir.pwd) changes.
  #
  # Root keeps a separate 'relative_paths' hash mapping aliases to their
  # relative paths. This hash allow reassignment if and when the root directory
  # changes.  By contrast, there is no separate data structure storing the
  # absolute paths. An absolute path thus has an alias in 'paths' but not
  # 'relative_paths', whereas relative paths have aliases in both.
  #
  # These features may be important to note when subclassing Root:
  # - root and all paths in 'paths' are expanded
  # - relative paths are stored in 'relative_paths'
  # - absolute paths are present in 'paths' but not in 'relative_paths'
  #
  class Root
    include Configurable
    include Utils
  
    # The root directory.
    config_attr(:root, '.', :writer => false, :init => false)
  
    # A hash of (alias, relative path) pairs for aliased paths relative
    # to root.
    config_attr(:relative_paths, {}, :writer => false, :init => false, :type => :hash)
  
    # A hash of (alias, relative path) pairs for aliased absolute paths.
    config_attr(:absolute_paths, {}, :reader => false, :writer => false, :init => false, :type => :hash)
  
    # A hash of (alias, expanded path) pairs for expanded relative and
    # absolute paths.
    attr_reader :paths
  
    # The filesystem root, inferred from self.root
    # (ex '/' on *nix or something like 'C:/' on Windows).
    attr_reader :path_root
  
    # Creates a new Root from the specified configurations.  A directory may be
    # provided instead of a configuration hash; in that case no aliased relative
    # or absolute paths are specified.  By default root is the present working
    # directory.
    def initialize(config_or_dir=Dir.pwd)
      # root, relative_paths, and absolute_paths are assigned manually as
      # an optimization (otherwise assign_paths would get called once for
      # each configuration)
      if config_or_dir.kind_of?(String)
        assign_paths(config_or_dir, {}, {})
        config_or_dir = {}
      else
        root = config_or_dir.delete(:root) || Dir.pwd
        relative_paths = config_or_dir.delete(:relative_paths) || {}
        absolute_paths = config_or_dir.delete(:absolute_paths) || {}
        assign_paths(root, relative_paths, absolute_paths)
      end
    
      initialize_config(config_or_dir)
    end
  
    # Sets the root directory. All paths are reassigned accordingly.
    def root=(path)
      assign_paths(path, relative_paths, absolute_paths)
    end

    # Sets the relative_paths to those provided. 'root' and :root are reserved
    # aliases and cannot be set using this method (use root= instead).
    #
    #   r = Root.new
    #   r['alt']                            # => File.join(r.root, 'alt')
    #   r.relative_paths = {'alt' => 'dir'}
    #   r['alt']                            # => File.join(r.root, 'dir')
    #
    def relative_paths=(paths)
      paths = Validation::HASH[paths]
      assign_paths(root, paths, absolute_paths)
    end
  
    # Sets the absolute paths to those provided. 'root' and :root are reserved
    # aliases and cannot be set using this method (use root= instead).
    #
    #   r = Root.new
    #   r['abs']                            # => File.join(r.root, 'abs')
    #   r.absolute_paths = {'abs' => '/path/to/dir'}
    #   r['abs']                            # => '/path/to/dir'
    #
    def absolute_paths=(paths)
      paths = Validation::HASH[paths]
      assign_paths(root, relative_paths, paths)
    end
  
    # Returns the absolute paths registered with self.
    def absolute_paths
      abs_paths = {}
      paths.each do |als, path|
        unless relative_paths.include?(als) || als.to_s == 'root'
          abs_paths[als] = path
        end
      end
      abs_paths
    end

    # Sets an alias for the path relative to the root directory.  The aliases
    # 'root' and :root cannot be set with this method (use root= instead).
    # Absolute paths can be set using the second syntax.  
    #
    #   r = Root.new '/root_dir'
    #   r[:dir] = 'path/to/dir'
    #   r[:dir]                             # => '/root_dir/path/to/dir'
    #
    #   r[:abs, true] = '/abs/path/to/dir'  
    #   r[:abs]                             # => '/abs/path/to/dir'
    #
    #-- 
    # Implementation Note:
    #
    # The syntax for setting an absolute path requires an odd use []=.  
    # In fact the method receives the arguments (:dir, true, '/abs/path/to/dir') 
    # rather than (:dir, '/abs/path/to/dir', true) meaning that internally path 
    # and absolute are switched when setting an absolute path.
    #
    def []=(als, path, absolute=false)
      raise ArgumentError, "the alias #{als.inspect} is reserved" if als.to_s == 'root'

      # switch the paths if absolute was provided
      unless absolute == false
        path, absolute = absolute, path
      end
    
      case
      when path.nil? 
        @relative_paths.delete(als)
        @paths.delete(als)
      when absolute
        @relative_paths.delete(als)
        @paths[als] = File.expand_path(path)
      else
        @relative_paths[als] = path
        @paths[als] = File.expand_path(File.join(root, path))
      end 
    end

    # Returns the expanded path for the specified alias.  If the alias has not
    # been set, then the path is inferred to be 'root/als'.  Expanded paths
    # are returned directly.
    #
    #   r = Root.new '/root_dir', :dir => 'path/to/dir'
    #   r[:dir]                             # => '/root_dir/path/to/dir'
    #
    #   r.path_root                         # => '/'
    #   r['relative/path']                  # => '/root_dir/relative/path'
    #   r['/expanded/path']                 # => '/expanded/path'
    #
    def [](als)
      path = self.paths[als] 
      return path unless path == nil
    
      als = als.to_s 
      expanded?(als) ? als : File.expand_path(File.join(root, als))
    end
  
    # Resolves the specified alias, joins paths together, and expands the
    # resulting path.
    def path(als, *paths)
      File.expand_path(File.join(self[als], *paths))
    end
  
    # Returns true if the path is relative to the specified alias.
    def relative?(als, path)
      super(self[als], path)
    end
  
    # Returns the part of path relative to the specified alias.
    def relative_path(als, path)
      super(self[als], path)
    end
  
    # Generates a path translated from the aliased source to the aliased target.
    # Raises an error if path is not relative to the source.
    # 
    #   r = Root.new '/root_dir'
    #   path = r.path(:in, 'path/to/file.txt')  # => '/root_dir/in/path/to/file.txt'
    #   r.translate(path, :in, :out)            # => '/root_dir/out/path/to/file.txt'
    #
    def translate(path, source_als, target_als)
      super(path, self[source_als], self[target_als])
    end

    # Globs for paths along the aliased path matching the input patterns.
    # Patterns should join with the aliased path make valid globs for 
    # Dir.glob.  If no patterns are specified, glob returns all paths
    # matching 'als/**/*'.
    def glob(als, *patterns)
      patterns << "**/*" if patterns.empty?
      patterns.collect! {|pattern| path(als, pattern)}
      super(*patterns)
    end

    # Lists all versions of path in the aliased dir matching the version
    # patterns. If no patterns are specified, then all versions of path
    # will be returned.
    def version_glob(als, path, *vpatterns)
      super(path(als, path), *vpatterns)
    end
  
    # Changes pwd to the specified directory using Root.chdir.
    def chdir(als, mkdir=false, &block)
      super(self[als], mkdir, &block)
    end
  
    # Constructs a path from the inputs and prepares it using
    # Root.prepare.  Returns the path.
    def prepare(als, *paths, &block)
      super(path(als, *paths), &block)
    end
  
    private
  
    # reassigns all paths with the input root, relative_paths, and absolute_paths
    def assign_paths(root, relative_paths, absolute_paths) # :nodoc:
      @root = File.expand_path(root)
      @relative_paths = {}
      @paths = {'root' => @root, :root => @root}

      @path_root = File.dirname(@root)
      while @path_root != (parent = File.dirname(@path_root))
        @path_root = parent 
      end
  
      relative_paths.each_pair {|dir, path| self[dir] = path }
      absolute_paths.each_pair {|dir, path| self[dir, true] = path }
    end  
  end
end