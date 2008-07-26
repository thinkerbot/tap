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
            raise "not a directory: #{dir}"
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
      # to it after minimization.  Paths are expanded before minimization.
      def minimize(paths)
        splits = paths.uniq.collect do |path|
          extname = File.extname(path)
          extname = '' if extname =~ /^\.\d+$/
          base = File.basename(path.chomp(extname))
          version = base =~ /(-\d+(\.\d+)*)$/ ? $1 : ''
          
          [File.dirname(path), base.chomp(version), extname, version, false]
        end

        mini_paths = []
        while !splits.empty?
          index = 0
          splits = splits.collect do |(dir, base, extname, version, flagged)|
            index += 1
            case
            when !flagged && just_one?(splits, index, base)
              mini_paths << base
              nil
            when dir.kind_of?(Array)
              if dir.empty?
                dir << File.dirname(base)
                base = File.basename(base)
              end
              
              case
              when extname.empty?
                mini_paths << "#{dir[0]}/#{base}"
                nil
                #raise "indistinguishable paths in: [#{paths.join(', ')}]"
              when version.empty?
                [dir, "#{base}#{extname}", '', version, false]
              else
                [dir, "#{base}#{version}", extname, '', false]
              end
            when (shift_base = File.basename(dir)) == dir
              [[], "#{shift_base}/#{base}", extname, version, false]
            else
              [File.dirname(dir), "#{shift_base}/#{base}", extname, version, false]
            end
          end.compact
        end
        
        if block_given?
          paths.each do |path|
            mini_path = mini_paths.find do |base|
              minimal_match?(path, base)
            end
            
            yield(path, mini_path || path)
          end
        end
        
        mini_paths
      end

      # Returns true if the mini_path matches path.  Matching logic
      # reverses that of minimize: 
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
        extname = File.extname(mini_path)
        extname = '' if extname =~ /^\.\d+$/
        version = mini_path =~ /(-\d+(\.\d+)*)#{extname}$/ ? $1 : ''
   
        match_path = case
        when !extname.empty?
          # force full match
          path
        when !version.empty?
          # match up to version
          path.chomp(File.extname(path))
        else
          # match up base
          path.chomp(File.extname(path)).sub(/(-\d+(\.\d+)*)$/, '')
        end
        
        # key ends with pattern AND basenames of each are equal... 
        # the last check ensures that a full path segment has 
        # been specified
        match_path[-mini_path.length, mini_path.length] == mini_path  && File.basename(match_path) == File.basename(mini_path)
      end
      
      # Minimizes the keys in a hash.  When reverse is true,
      # minimal_map re-maps the hash values to the minimized
      # key.  In reverse mode, redundant values raise an error. 
      def minimal_map(hash, reverse=false)
        results = {}
        if reverse
          minimize(hash.keys) do |p, mp|
            value = hash[p]
            raise "redundant value in reverse minimal_map: #{value}" if results.has_key?(value)
            results[value] = mp
          end
        else
          minimize(hash.keys) {|p, mp| results[mp] = hash[p] }
        end
        results
      end
      
      # Returns the path segments for the given path, splitting along the path 
      # divider.  Root paths are always represented by a string, if only an 
      # empty string.
      #
      #   os          divider    example
      #   windows     '\'        Root.split('C:\path\to\file')  # => ["C:", "path", "to", "file"]
      #   *nix        '/'        Root.split('/path/to/file')    # => ["", "path", "to", "file"]
      # 
      # The path is always expanded relative to the expand_dir; so '.' and '..' are 
      # resolved.  However, unless expand_path == true, only the segments relative
      # to the expand_dir are returned.  
      #
      # On windows (note that expanding paths allows the use of slashes or backslashes):
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
      unless relative_path = relative_filepath(input_dir, filepath)
        raise "\n#{filepath}\nis not relative to:\n#{input_dir}"
      end
      filepath(output_dir, relative_path)
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