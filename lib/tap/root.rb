require 'tap/support/versions'
require 'tap/support/configurable'
autoload(:FileUtils, 'fileutils')

module Tap
  
  # Root allows you to define a root directory and alias subdirectories, so that  
  # you can conceptualize what filepaths you need without predefining the full 
  # filepaths.  Root also simplifies operations on filepaths.
  #
  #  # define a root directory with aliased subdirectories
  #  r = Root.new '/root_dir', :input => 'in', :output => 'out'
  #  
  #  # work with directories
  #  r[:input]                                   # => '/root_dir/in'
  #  r[:output]                                  # => '/root_dir/out'
  #  r['implicit']                               # => '/root_dir/implicit'
  #
  #  # expanded paths are returned unchanged
  #  r[File.expand_path('expanded')]             # => File.expand_path('expanded')
  #
  #  # work with filepaths
  #  fp = r.filepath(:input, 'path/to/file.txt') # => '/root_dir/in/path/to/file.txt'
  #  r.relative_filepath(:input, fp)             # => 'path/to/file.txt'
  #  r.translate(fp, :input, :output)            # => '/root_dir/out/path/to/file.txt'
  #  
  #  # version filepaths
  #  r.version('path/to/config.yml', 1.0)        # => 'path/to/config-1.0.yml'
  #  r.increment('path/to/config-1.0.yml', 0.1)  # => 'path/to/config-1.1.yml'
  #  r.deversion('path/to/config-1.1.yml')       # => ['path/to/config.yml', "1.1"]
  #
  #  # absolute paths can also be aliased 
  #  r[:abs, true] = "/absolute/path"      
  #  r.filepath(:abs, "to", "file.txt")          # => '/absolute/path/to/file.txt'
  #
  # By default, Roots are initialized to the present working directory (Dir.pwd).
  # As in the 'implicit' example, Root infers a path relative to the root directory
  # whenever it needs to resolve an alias that is not explicitly set.  The only 
  # exceptions to this are fully expanded paths.  These are returned unchanged.
  #
  # === Implementation Notes
  #
  # Internally Root stores expanded paths all aliased paths in the 'paths' hash.  
  # Expanding paths ensures they remain constant even when the present working 
  # directory (Dir.pwd) changes.
  #
  # Root keeps a separate 'directories' hash mapping aliases to their subdirectory paths.  
  # This hash allow reassignment if and when the root directory changes.  By contrast, 
  # there is no separate data structure storing the absolute paths. An absolute path 
  # thus has an alias in 'paths' but not 'directories', whereas subdirectory paths
  # have aliases in both.
  #
  # These features may be important to note when subclassing Root:
  # - root and all filepaths in 'paths' are expanded
  # - subdirectory paths are stored in 'directories'
  # - absolute paths are present in 'paths' but not in 'directories'
  #
  class Root
    # Regexp to match a windows-style root filepath.
    WIN_ROOT_PATTERN = /^[A-z]:\//
    
    class << self
      include Support::Versions
      
      # Returns the filepath of path relative to dir.  Both dir and path are
      # expanded before the relative filepath is determined.  An error is 
      # raised if the path is not relative to dir.
      #
      #   Root.relative_filepath('dir', "dir/path/to/file.txt")  # => "path/to/file.txt"
      #
      def relative_filepath(dir, path, dir_string=Dir.pwd)
        expanded_dir = File.expand_path(dir, dir_string)
        expanded_path = File.expand_path(path, dir_string)
  
        unless expanded_path.index(expanded_dir) == 0
          raise "\n#{expanded_path}\nis not relative to:\n#{expanded_dir}"
        end
      
        # use dir.length + 1 to remove a leading '/'.   If dir.length + 1 >= expanded.length 
        # as in: relative_filepath('/path', '/path') then the first arg returns nil, and an 
        # empty string is returned
        expanded_path[( expanded_dir.chomp("/").length + 1)..-1] || ""
      end
    
      # Lists all unique paths matching the input glob patterns.  
      def glob(*patterns)
        patterns.collect do |pattern| 
          Dir.glob(pattern)
        end.flatten.uniq
      end
    
      # Lists all unique versions of path matching the glob version patterns.  
      # If no patterns are specified, then all versions of path will be returned.
      def vglob(path, *vpatterns)
        vpatterns << "*" if vpatterns.empty?
        vpatterns.collect do |vpattern| 
          results = Dir.glob(version(path, vpattern)) 
    
          # extra work to include the default version path for any version
          results << path if vpattern == "*" && File.exists?(path)
          results
        end.flatten.uniq
      end
      
      # Path suffix glob.  Globs along the base paths for 
      # paths that match the specified suffix pattern.
      def sglob(suffix_pattern, *base_paths)
        base_paths.collect do |base|
          base = File.expand_path(base)
          Dir.glob(File.join(base, suffix_pattern))
        end.flatten.uniq
      end
      
      # Executes the block in the specified directory.  Makes the directory, if
      # necessary when mkdir is specified.  Otherwise, indir raises an error 
      # for non-existant directories, as well as non-directory inputs.
      def indir(dir, mkdir=false)
        unless File.directory?(dir)
          if !File.exists?(dir) && mkdir
            FileUtils.mkdir_p(dir)
          else
            raise "non a directory: #{dir}"
          end
        end

        pwd = Dir.pwd
        begin
          Dir.chdir(dir)
          yield
        ensure
          Dir.chdir(pwd)
        end
      end
      
      # The path root type indicating windows, *nix, or some unknown
      # style of filepaths (:win, :nix, :unknown).
      def path_root_type
        @path_root_type ||= case
        when RUBY_PLATFORM =~ /mswin/ && File.expand_path(".") =~ WIN_ROOT_PATTERN then :win 
        when File.expand_path(".")[0] == ?/ then :nix
        else :unknown
        end
      end
      
      # Returns true if the input path appears to be an expanded path,
      # based on Root.path_root_type.  
      #
      # If root_type == :win returns true if the path matches 
      # WIN_ROOT_PATTERN.
      #
      #   Root.expanded_path?('C:/path')  # => true
      #   Root.expanded_path?('c:/path')  # => true
      #   Root.expanded_path?('D:/path')  # => true
      #   Root.expanded_path?('path')     # => false
      #
      # If root_type == :nix, then expanded? returns true if 
      # the path begins with '/'.
      #
      #   Root.expanded_path?('/path')  # => true
      #   Root.expanded_path?('path')   # => false
      #
      # Otherwise expanded_path? always returns nil.
      def expanded_path?(path, root_type=path_root_type)
        case root_type
        when :win 
          path =~ WIN_ROOT_PATTERN ? true : false
        when :nix  
          path[0] == ?/
        else
          nil
        end
      end
      
      # Reduces a set of paths to the unique minimum set of basename identifiers
      # for the paths.  For example:
      #
      #   Root.reduce('to/file.txt', 'path/to/file.txt', 'path/to/another/file.txt')
      #   # => ['to/file.txt', 'another/file.txt']
      #
      # Each of the non-reduced paths maps to one of the reduced paths, based
      # on the end part of the path string.  Paths are expanded before reduction.
      def reduce(paths)
        splits = paths.uniq.collect do |path|
          [File.dirname(path), File.basename(path)]
        end
        
        base_paths = []
        while !splits.empty?
          splits = splits.collect do |(dir, base)|
            if splits.inject(0) {|count, (d,b)| b == base ? count + 1 : count} == 1
              base_paths << base
              nil
            else
              [File.dirname(dir), "#{File.basename(dir)}/#{base}"]
            end
          end.compact
        end
        
        if block_given?
          paths.each do |path|
            base_path = base_paths.find do |base| 
              path[-base.length, base.length] == base 
            end
            
            yield(path, base_path)
          end
        end 
        
        base_paths
      end
      
      def reduce_map(map, reverse=false)
        results = {}
        if reverse
          reduce(map.keys) {|p, rp| results[map[p]] = rp }
        else
          reduce(map.keys) {|p, rp| results[rp] = map[p] }
        end
        results
      end
    end
  
    include Support::Versions
    include Support::Configurable

    # The root directory.
    config_attr(:root, '.', :writer => false)
    
    # A hash of (alias, relative path) pairs for aliased subdirectories.
    config_attr(:directories, {}, :writer => false)
    
    # A hash of (alias, relative path) pairs for aliased absolute paths.
    config_attr(:absolute_paths, {}, :reader => false, :writer => false)
    
    # A hash of (alias, expanded path) pairs for aliased subdirectories and absolute paths.
    attr_reader :paths
    
    # The filesystem root, inferred from self.root
    # (ex '/' on *nix or something like 'C:/' on Windows).
    attr_reader :path_root
    
    # Creates a new Root with the given root directory, aliased directories
    # and absolute paths.  By default root is the present working directory 
    # and no aliased directories or absolute paths are specified.  
    def initialize(root=Dir.pwd, directories={}, absolute_paths={})
      assign_paths(root, directories, absolute_paths)
      @config = self.class.configurations.instance_config(self)
    end
    
    # Sets the root directory. All paths are reassigned accordingly.
    def root=(path)
      assign_paths(path, directories, absolute_paths)
    end
  
    # Sets the directories to those provided. 'root' and :root are reserved
    # and cannot be set using this method (use root= instead).
    #
    # r['alt'] # => File.join(r.root, 'alt')
    # r.directories = {'alt' => 'dir'}
    # r['alt'] # => File.join(r.root, 'dir')
    def directories=(dirs)
      assign_paths(root, dirs, absolute_paths)
    end
    
    # Sets the absolute paths to those provided. 'root' and :root are reserved
    # directory keys and cannot be set using this method (use root= instead).
    #
    # r['abs'] # => File.join(r.root, 'abs')
    # r.absolute_paths = {'abs' => '/path/to/dir'}
    # r['abs'] # => '/path/to/dir'
    def absolute_paths=(paths)
      assign_paths(root, directories, paths)
    end
    
    # Returns the absolute paths registered with self.
    def absolute_paths
      abs_paths = {}
      paths.each do |da, path| 
        abs_paths[da] = path unless directories.include?(da) || da.to_s == 'root'
      end
      abs_paths
    end

    # Sets an alias for the subdirectory relative to the root directory.  
    # The aliases 'root' and :root cannot be set with this method 
    # (use root= instead).  Absolute filepaths can be set using the 
    # second syntax.  
    #
    #  r = Root.new '/root_dir'
    #  r[:dir] = 'path/to/dir'
    #  r[:dir]       # => '/root_dir/path/to/dir'
    #
    #  r[:abs, true] = '/abs/path/to/dir'  
    #  r[:abs]       # => '/abs/path/to/dir'
    # 
    #--
    # Implementation Notes:
    # The syntax for setting an absolute filepath requires an odd use []=.  
    # In fact the method recieves the arguments (:dir, true, '/abs/path/to/dir') 
    # rather than (:dir, '/abs/path/to/dir', true), meaning that internally path 
    # and absolute are switched when setting an absolute filepath.
    #++
    def []=(dir, path, absolute=false)
      raise ArgumentError, "The directory key '#{dir}' is reserved." if dir.to_s == 'root'
  
      # switch the paths if absolute was provided
      unless absolute == false
        switch = path
        path = absolute
        absolute = switch
      end
      
      case
      when path.nil? 
        @directories.delete(dir)
        @paths.delete(dir)
      when absolute
        @directories.delete(dir)
        @paths[dir] = File.expand_path(path)
      else
        @directories[dir] = path
        @paths[dir] = File.expand_path(File.join(root, path))
      end 
    end
  
    # Returns the expanded path for the specified alias.  If the alias 
    # has not been set, then the path is inferred to be 'root/dir' unless
    # the path is relative to path_root.  These paths are returned 
    # directly.
    #
    #  r = Root.new '/root_dir', :dir => 'path/to/dir'
    #  r[:dir]                 # => '/root_dir/path/to/dir'
    #
    #  r.path_root             # => '/'
    #  r['relative/path']      # => '/root_dir/relative/path'
    #  r['/expanded/path']     # => '/expanded/path'
    #
    def [](dir)
      path = self.paths[dir] 
      return path unless path == nil
      
      dir = dir.to_s 
      Root.expanded_path?(dir) ? dir : File.expand_path(File.join(root, dir))
    end
    
    # Constructs expanded filepaths relative to the path of the specified alias. 
    def filepath(dir, *filename)
      # TODO - consider filename.compact so nils will not raise errors
      File.expand_path(File.join(self[dir], *filename))
    end
  
    # Retrieves the filepath relative to the path of the specified alias.  
    def relative_filepath(dir, filepath)
      Root.relative_filepath(self[dir], filepath)
    end
  
    # Generates a target filepath translated from the aliased input dir to 
    # the aliased output dir. Raises an error if the filepath is not relative 
    # to the aliased input dir.
    # 
    #  fp = r.filepath(:in, 'path/to/file.txt')    # => '/root_dir/in/path/to/file.txt'
    #  r.translate(fp, :in, :out)                  # => '/root_dir/out/path/to/file.txt'
    def translate(filepath, input_dir, output_dir)
      filepath(output_dir, relative_filepath(input_dir, filepath))
    end
  
    # Lists all files in the aliased dir matching the input patterns.  Patterns 
    # should be valid inputs for +Dir.glob+.  If no patterns are specified, lists 
    # all files/folders matching '**/*'.
    def glob(dir, *patterns)
      patterns << "**/*" if patterns.empty?
      patterns.collect! {|pattern| filepath(dir, pattern)}
      Root.glob(*patterns)
    end
  
    # Lists all versions of filename in the aliased dir matching the version patterns.
    # If no patterns are specified, then all versions of filename will be returned.
    def vglob(dir, filename, *vpatterns)
      Root.vglob(filepath(dir, filename), *vpatterns)
    end
    
    # Executes the provided block in the specified directory using Root.indir.
    def indir(dir, mkdir=false)
      Root.indir(self[dir], mkdir) { yield }
    end
    
    private
  
    # reassigns all paths with the input root, directories, and absolute_paths
    def assign_paths(root, directories, absolute_paths)
      @root = File.expand_path(root)
      @directories = {}
      @paths = {'root' => @root, :root => @root}

      @path_root = File.dirname(@root)
      while @path_root != (parent = File.dirname(@path_root))
        @path_root = parent 
      end
    
      directories.each_pair {|dir, path| self[dir] = path }
      absolute_paths.each_pair {|dir, path| self[dir, true] = path }
    end  

  end
end