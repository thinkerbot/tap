require 'configurable'
require 'tap/support/versions'
autoload(:FileUtils, 'fileutils')

module Tap
  
  # Root allows you to define a root directory and alias relative paths, so
  # that you can conceptualize what filepaths you need without predefining the
  # full filepaths.  Root also simplifies operations on filepaths.
  #
  #   # define a root directory with aliased relative paths
  #   r = Root.new '/root_dir', :input => 'in', :output => 'out'
  #  
  #   # work with aliases
  #   r[:input]                                   # => '/root_dir/in'
  #   r[:output]                                  # => '/root_dir/out'
  #   r['implicit']                               # => '/root_dir/implicit'
  #
  #   # expanded paths are returned unchanged
  #   r[File.expand_path('expanded')]             # => File.expand_path('expanded')
  #
  #   # work with filepaths
  #   fp = r.filepath(:input, 'path/to/file.txt') # => '/root_dir/in/path/to/file.txt'
  #   r.relative_filepath(:input, fp)             # => 'path/to/file.txt'
  #   r.translate(fp, :input, :output)            # => '/root_dir/out/path/to/file.txt'
  #  
  #   # version filepaths
  #   r.version('path/to/config.yml', 1.0)        # => 'path/to/config-1.0.yml'
  #   r.increment('path/to/config-1.0.yml', 0.1)  # => 'path/to/config-1.1.yml'
  #   r.deversion('path/to/config-1.1.yml')       # => ['path/to/config.yml', "1.1"]
  #
  #   # absolute paths can also be aliased 
  #   r[:abs, true] = "/absolute/path"      
  #   r.filepath(:abs, "to", "file.txt")          # => '/absolute/path/to/file.txt'
  #
  # By default, Roots are initialized to the present working directory
  # (Dir.pwd).
  #
  #--
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
  # - root and all filepaths in 'paths' are expanded
  # - relative paths are stored in 'relative_paths'
  # - absolute paths are present in 'paths' but not in 'relative_paths'
  #
  class Root
    # Regexp to match a windows-style root filepath.
    WIN_ROOT_PATTERN = /^[A-z]:\//
    
    class << self
      include Support::Versions
      
      # Returns the filepath of path relative to dir.  Both dir and path are
      # expanded before the relative filepath is determined.  Returns nil if 
      # the path is not relative to dir.
      #
      #   Root.relative_filepath('dir', "dir/path/to/file.txt")  # => "path/to/file.txt"
      #
      def relative_filepath(dir, path, dir_string=Dir.pwd)
        expanded_dir = File.expand_path(dir, dir_string)
        expanded_path = File.expand_path(path, dir_string)
  
        return nil unless expanded_path.index(expanded_dir) == 0
      
        # use dir.length + 1 to remove a leading '/'.   If dir.length + 1 >= expanded.length 
        # as in: relative_filepath('/path', '/path') then the first arg returns nil, and an 
        # empty string is returned
        expanded_path[(expanded_dir.chomp("/").length + 1)..-1] || ""
      end
      
      # Generates a target filepath translated from the source_dir to the
      # target_dir. Raises an error if the filepath is not relative to the
      # source_dir.    
      #
      #    Root.translate("/path/to/file.txt", "/path", "/another/path")  # => '/another/path/to/file.txt'
      #
      def translate(path, source_dir, target_dir)
        unless relative_path = relative_filepath(source_dir, path)
          raise ArgumentError, "\n#{path}\nis not relative to:\n#{source_dir}"
        end
        File.join(target_dir, relative_path)
      end
      
      # Returns the path, exchanging the extension with extname.  Extname may
      # optionally omit the leading period.
      #
      #   Root.exchange('path/to/file.txt', '.html')  # => 'path/to/file.html'
      #   Root.exchange('path/to/file.txt', 'rb')     # => 'path/to/file.rb'
      #
      def exchange(path, extname)
        "#{path.chomp(File.extname(path))}#{extname[0] == ?. ? '' : '.'}#{extname}"
      end
    
      # Lists all unique paths matching the input glob patterns.  
      def glob(*patterns)
        patterns.collect do |pattern| 
          Dir.glob(pattern)
        end.flatten.uniq
      end
    
      # Lists all unique versions of path matching the glob version patterns. If
      # no patterns are specified, then all versions of path will be returned.
      def vglob(path, *vpatterns)
        vpatterns << "*" if vpatterns.empty?
        vpatterns.collect do |vpattern| 
          results = Dir.glob(version(path, vpattern)) 
    
          # extra work to include the default version path for any version
          results << path if vpattern == "*" && File.exists?(path)
          results
        end.flatten.uniq
      end
      
      # Path suffix glob.  Globs along the base paths for paths that match the
      # specified suffix pattern.
      def sglob(suffix_pattern, *base_paths)
        base_paths.collect do |base|
          base = File.expand_path(base)
          Dir.glob(File.join(base, suffix_pattern))
        end.flatten.uniq
      end
      
      # Like Dir.chdir but makes the directory, if necessary, when mkdir is 
      # specified. chdir raises an error for non-existant directories, as well
      # as non-directory inputs.
      def chdir(dir, mkdir=false, &block)
        dir = File.expand_path(dir)
        
        unless File.directory?(dir)
          if !File.exists?(dir) && mkdir
            FileUtils.mkdir_p(dir)
          else
            raise ArgumentError, "not a directory: #{dir}"
          end
        end
        
        Dir.chdir(dir, &block)
      end
      
      # Prepares the input path by making the parent directory for path. If a
      # block is given, a file is created at path and passed to it; in this
      # way files with non-existant parent directories are readily made.
      #
      # Returns path.
      def prepare(path, &block)
        dirname = File.dirname(path)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        File.open(path, "w", &block) if block_given?
        path
      end
      
      # The path root type indicating windows, *nix, or some unknown style of
      # filepaths (:win, :nix, :unknown).
      def path_root_type
        @path_root_type ||= case
        when RUBY_PLATFORM =~ /mswin/ && File.expand_path(".") =~ WIN_ROOT_PATTERN then :win 
        when File.expand_path(".")[0] == ?/ then :nix
        else :unknown
        end
      end
      
      # Returns true if the input path appears to be an expanded path, based on
      # Root.path_root_type.  
      #
      # If root_type == :win returns true if the path matches WIN_ROOT_PATTERN.
      #
      #   Root.expanded?('C:/path')  # => true
      #   Root.expanded?('c:/path')  # => true
      #   Root.expanded?('D:/path')  # => true
      #   Root.expanded?('path')     # => false
      #
      # If root_type == :nix, then expanded? returns true if the path begins
      # with '/'.
      #
      #   Root.expanded?('/path')  # => true
      #   Root.expanded?('path')   # => false
      #
      # Otherwise expanded? always returns nil.
      def expanded?(path, root_type=path_root_type)
        case root_type
        when :win 
          path =~ WIN_ROOT_PATTERN ? true : false
        when :nix  
          path[0] == ?/
        else
          nil
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
      
      # Minimizes a set of paths to the set of shortest basepaths that unqiuely 
      # identify the paths.  The path extension and versions are removed from
      # the basepath if possible.  For example:
      #
      #   Tap::Root.minimize ['path/to/a.rb', 'path/to/b.rb']
      #   # => ['a', 'b']
      #
      #   Tap::Root.minimize ['path/to/a-0.1.0.rb', 'path/to/b-0.1.0.rb']
      #   # => ['a', 'b']
      #
      #   Tap::Root.minimize ['path/to/file.rb', 'path/to/file.txt']
      #   # => ['file.rb', 'file.txt']
      #
      #   Tap::Root.minimize ['path-0.1/to/file.rb', 'path-0.2/to/file.rb']
      #   # => ['path-0.1/to/file', 'path-0.2/to/file']
      #
      # Minimized paths that carry their extension will always carry
      # their version as well, but the converse is not true; paths
      # can be minimized to carry just the version and not the path
      # extension.
      #
      #   Tap::Root.minimize ['path/to/a-0.1.0.rb', 'path/to/a-0.1.0.txt']
      #   # => ['a-0.1.0.rb', 'a-0.1.0.txt']
      #
      #   Tap::Root.minimize ['path/to/a-0.1.0.rb', 'path/to/a-0.2.0.rb']
      #   # => ['a-0.1.0', 'a-0.2.0']
      #
      # If a block is given, each (path, mini-path) pair will be passed
      # to it after minimization.
      def minimize(paths) # :yields: path, mini_path
        unless block_given?
          mini_paths = []
          minimize(paths) {|p, mp| mini_paths << mp }
          return mini_paths  
        end
        
        splits = paths.uniq.collect do |path|
          extname = File.extname(path)
          extname = '' if extname =~ /^\.\d+$/
          base = File.basename(path.chomp(extname))
          version = base =~ /(-\d+(\.\d+)*)$/ ? $1 : ''
          
          [dirname_or_array(path), base.chomp(version), extname, version, false, path]
        end

        while !splits.empty?
          index = 0
          splits = splits.collect do |(dir, base, extname, version, flagged, path)|
            index += 1
            case
            when !flagged && just_one?(splits, index, base)
              
              # found just one
              yield(path, base)
              nil
            when dir.kind_of?(Array)
              
              # no more path segments to use, try to add
              # back version and extname
              if dir.empty?
                dir << File.dirname(base)
                base = File.basename(base)
              end
              
              case
              when !version.empty?
                # add back version (occurs first)
                [dir, "#{base}#{version}", extname, '', false, path]
                
              when !extname.empty?
                
                # add back extension (occurs second)
                [dir, "#{base}#{extname}", '', version, false, path]
              else
                
                # nothing more to distinguish... path is minimized (occurs third)
                yield(path, min_join(dir[0], base))
                nil
              end
            else

              # shift path segment.  dirname_or_array returns an
              # array if this is the last path segment to shift.
              [dirname_or_array(dir), min_join(File.basename(dir), base), extname, version, false, path]
            end
          end.compact
        end
      end
      
      # Returns true if the mini_path matches path.  Matching logic reverses
      # that of minimize:
      #
      # * a match occurs when path ends with mini_path
      # * if mini_path doesn't specify an extension, then mini_path
      #   must only match path up to the path extension
      # * if mini_path doesn't specify a version, then mini_path
      #   must only match path up to the path basename (minus the
      #   version and extname)
      #
      # For example:
      #
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file')           # => true
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'dir/file')       # => true
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0')     # => true
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0.rb')  # => true
      #
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file.rb')        # => false
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.2.0')     # => false
      #   Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'another')        # => false
      #
      # In matching, partial basenames are not allowed but partial directories
      # are allowed.  Hence:
      #
      #   Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'file')          # => true
      #   Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'ile')           # => false
      #   Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'r/file')        # => true
      #
      def minimal_match?(path, mini_path)
        extname = non_version_extname(mini_path)
        version = mini_path =~ /(-\d+(\.\d+)*)#{extname}$/ ? $1 : ''
   
        match_path = case
        when !extname.empty?
          # force full match
          path
        when !version.empty?
          # match up to version
          path.chomp(non_version_extname(path))
        else
          # match up base
          path.chomp(non_version_extname(path)).sub(/(-\d+(\.\d+)*)$/, '')
        end
        
        # key ends with pattern AND basenames of each are equal... 
        # the last check ensures that a full path segment has 
        # been specified
        match_path[-mini_path.length, mini_path.length] == mini_path  && File.basename(match_path) == File.basename(mini_path)
      end
      
      # Returns the path segments for the given path, splitting along the path 
      # divider.  Root paths are always represented by a string, if only an 
      # empty string.
      #
      #   os          divider    example
      #   windows     '\'        Root.split('C:\path\to\file')  # => ["C:", "path", "to", "file"]
      #   *nix        '/'        Root.split('/path/to/file')    # => ["", "path", "to", "file"]
      # 
      # The path is always expanded relative to the expand_dir; so '.' and
      # '..' are resolved.  However, unless expand_path == true, only the
      # segments relative to the expand_dir are returned.  
      #
      # On windows (note that expanding paths allows the use of slashes or
      # backslashes):
      #
      #   Dir.pwd                                               # => 'C:/'
      #   Root.split('path\to\..\.\to\file')                    # => ["C:", "path", "to", "file"]
      #   Root.split('path/to/.././to/file', false)             # => ["path", "to", "file"]
      #
      # On *nix (or more generally systems with '/' roots):
      #
      #   Dir.pwd                                               # => '/'
      #   Root.split('path/to/.././to/file')                    # => ["", "path", "to", "file"]
      #   Root.split('path/to/.././to/file', false)             # => ["path", "to", "file"]
      #
      def split(path, expand_path=true, expand_dir=Dir.pwd)
        path = if expand_path
          File.expand_path(path, expand_dir)
        else
          # normalize the path by expanding it, then
          # work back to the relative filepath as needed
          expanded_dir = File.expand_path(expand_dir)
          expanded_path = File.expand_path(path, expand_dir)
          expanded_path.index(expanded_dir) != 0 ? expanded_path : Tap::Root.relative_filepath(expanded_dir, expanded_path)
        end

        segments = path.scan(/[^\/]+/)

        # add back the root filepath as needed on *nix 
        segments.unshift "" if path[0] == ?/
        segments
      end
      
      private
      
      # utility method for minimize -- joins the
      # dir and path, preventing results like:
      #
      #   "./path"
      #   "//path"
      #
      def min_join(dir, path) # :nodoc:
        case dir
        when "." then path
        when "/" then "/#{path}"
        else "#{dir}/#{path}"
        end
      end
      
      # utility method for minimize -- returns the 
      # dirname of path, or an array if the dirname
      # is effectively empty.
      def dirname_or_array(path) # :nodoc:
        dir = File.dirname(path)
        case dir
        when path, '.' then []
        else dir
        end
      end
      
      # utility method for minimize -- determines if there 
      # is just one of the base in splits, while flagging
      # all matching entries.
      def just_one?(splits, index, base) # :nodoc:
        just_one = true
        index.upto(splits.length-1) do |i|
          if splits[i][1] == base
            splits[i][4] = true
            just_one = false
          end
        end
        
        just_one
      end
      
      # utility method for minimal_match --  returns a non-version 
      # extname, or an empty string if the path ends in a version.
      def non_version_extname(path) # :nodoc:
        extname = File.extname(path)
        extname =~ /^\.\d+$/ ? '' : extname
      end
      
    end
    
    include Configurable
    include Support::Versions
    
    # The root directory.
    config_attr(:root, '.', :writer => false)
    
    # A hash of (alias, relative path) pairs for aliased paths relative
    # to root.
    config_attr(:relative_paths, {}, :writer => false)
    
    # A hash of (alias, relative path) pairs for aliased absolute paths.
    config_attr(:absolute_paths, {}, :reader => false, :writer => false)
    
    # A hash of (alias, expanded path) pairs for expanded relative and
    # absolute paths.
    attr_reader :paths
    
    # The filesystem root, inferred from self.root
    # (ex '/' on *nix or something like 'C:/' on Windows).
    attr_reader :path_root
    
    # Creates a new Root with the given root directory, aliased relative paths
    # and absolute paths.  By default root is the present working directory 
    # and no aliased relative or absolute paths are specified.  
    def initialize(root=Dir.pwd, relative_paths={}, absolute_paths={})
      assign_paths(root, relative_paths, absolute_paths)
      @config = DelegateHash.new(self.class.configurations, {}, self)
    end
    
    # Sets the root directory. All paths are reassigned accordingly.
    def root=(path)
      assign_paths(path, relative_paths, absolute_paths)
    end
  
    # Sets the relative_paths to those provided. 'root' and :root are reserved
    # aliases and cannot be set using this method (use root= instead).
    #
    #   r = Tap::Root.new
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
    #   r = Tap::Root.new
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
    # Absolute filepaths can be set using the second syntax.  
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
    # The syntax for setting an absolute filepath requires an odd use []=.  
    # In fact the method recieves the arguments (:dir, true, '/abs/path/to/dir') 
    # rather than (:dir, '/abs/path/to/dir', true), meaning that internally path 
    # and absolute are switched when setting an absolute filepath.
    #
    def []=(als, path, absolute=false)
      raise ArgumentError, "the alias #{als.inspect} is reserved" if als.to_s == 'root'
  
      # switch the paths if absolute was provided
      unless absolute == false
        switch = path
        path = absolute
        absolute = switch
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
      Root.expanded?(als) ? als : File.expand_path(File.join(root, als))
    end
    
    # Resolves the specified alias, joins the paths together, and expands the
    # resulting filepath.
    def filepath(als, *paths)
      File.expand_path(File.join(self[als], *paths))
    end
  
    # Retrieves the filepath relative to the path of the specified alias.  
    def relative_filepath(als, path)
      Root.relative_filepath(self[als], path)
    end
    
    # Same as filepath but raises an error if the result is not a subpath of
    # the aliased directory.
    def subpath(als, *paths)
      dir = self[als]
      path = filepath(als, *paths)
      
      if path.rindex(dir, 0) != 0
        raise "not a subpath: #{path} (#{dir})"
      end
      
      path
    end
  
    # Generates a filepath translated from the aliased source dir to the
    # aliased target dir. Raises an error if the filepath is not relative
    # to the source dir.
    # 
    #   r = Tap::Root.new '/root_dir'
    #   path = r.filepath(:in, 'path/to/file.txt')    # => '/root_dir/in/path/to/file.txt'
    #   r.translate(path, :in, :out)                  # => '/root_dir/out/path/to/file.txt'
    #
    def translate(path, source_als, target_als)
      Root.translate(path, self[source_als], self[target_als])
    end
  
    # Lists all files along the aliased path matching the input patterns.
    # Patterns should join with the aliased path make valid globs for 
    # Dir.glob.  If no patterns are specified, glob returns all paths
    # matching 'als/**/*'.
    def glob(als, *patterns)
      patterns << "**/*" if patterns.empty?
      patterns.collect! {|pattern| filepath(als, pattern)}
      Root.glob(*patterns)
    end
  
    # Lists all versions of path in the aliased dir matching the version
    # patterns. If no patterns are specified, then all versions of path
    # will be returned.
    def vglob(als, path, *vpatterns)
      Root.vglob(filepath(als, path), *vpatterns)
    end
    
    # Changes pwd to the specified directory using Root.chdir.
    def chdir(als, mkdir=false, &block)
      Root.chdir(self[als], mkdir, &block)
    end
    
    # Constructs a path from the inputs (using filepath) and prepares it using
    # Root.prepare.  Returns the path.
    def prepare(als, *paths, &block)
      Root.prepare(filepath(als, *paths), &block)
    end
    
    private
  
    # reassigns all paths with the input root, relative_paths, and absolute_paths
    def assign_paths(root, relative_paths, absolute_paths)
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