require 'tap/root/versions'
autoload(:FileUtils, 'fileutils')

module Tap
  class Root
  
    # A variety of utility methods for working with paths.
    module Utils
      include Versions
    
      # Regexp to match a windows-style root path.
      WIN_ROOT_PATTERN = /^[A-z]:\//
    
      module_function
    
      # Returns the path of 'path' relative to dir.  Both dir and path will
      # be expanded to dir_string, if specified, before the relative path is
      # determined.  Returns nil if the path is not relative to dir.
      #
      #   relative_path('dir', "dir/path/to/file.txt")  # => "path/to/file.txt"
      #
      def relative_path(dir, path, dir_string=Dir.pwd)
        if dir_string
          dir = File.expand_path(dir, dir_string)
          path = File.expand_path(path, dir_string)
        end
        return nil unless Utils.relative?(dir, path, false)
    
        # use dir.length + 1 to remove a leading '/'.   If dir.length + 1 >= expanded.length 
        # as in: relative_path('/path', '/path') then the first arg returns nil, and an 
        # empty string is returned
        path[(dir.chomp("/").length + 1)..-1] || ""
      end
    
      # Generates a target path translated from the source_dir to the
      # target_dir. Raises an error if the path is not relative to the
      # source_dir.    
      #
      #    translate("/path/to/file.txt", "/path", "/another/path")  # => '/another/path/to/file.txt'
      #
      def translate(path, source_dir, target_dir)
        unless relative_path = relative_path(source_dir, path)
          raise ArgumentError, "\n#{path}\nis not relative to:\n#{source_dir}"
        end
        File.join(target_dir, relative_path)
      end
    
      # Returns the path, exchanging the extension with extname.  Extname may
      # optionally omit the leading period.
      #
      #   exchange('path/to/file.txt', '.html')  # => 'path/to/file.html'
      #   exchange('path/to/file.txt', 'rb')     # => 'path/to/file.rb'
      #
      def exchange(path, extname)
        "#{path.chomp(File.extname(path))}#{extname[0] == ?. ? '' : '.'}#{extname}"
      end
  
      # Lists all unique paths matching the input glob patterns.  
      def glob(*patterns)
        Dir[*patterns].uniq
      end
  
      # Lists all unique versions of path matching the glob version patterns. If
      # no patterns are specified, then all versions of path will be returned.
      def version_glob(path, *vpatterns)
        paths = []
      
        vpatterns << "*" if vpatterns.empty?
        vpatterns.each do |vpattern| 
          paths.concat Dir.glob(version(path, vpattern)) 
  
          # extra work to include the default version path for any version
          paths << path if vpattern == "*" && File.exists?(path)
        end
      
        paths.uniq
      end
    
      # Path suffix glob.  Globs along the paths for the specified suffix
      # pattern.
      def suffix_glob(suffix_pattern, *paths)
        paths.collect! {|path| File.join(path, suffix_pattern) }
        Dir[*paths].uniq
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
      def prepare(path)
        dirname = File.dirname(path)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        File.open(path, "w") {|io| yield(io) } if block_given?
        path
      end
    
      # The path root type indicating windows, *nix, or some unknown style of
      # paths (:win, :nix, :unknown).
      def path_root_type
        @path_root_type ||= case
        when RUBY_PLATFORM =~ /mswin/ && File.expand_path(".") =~ WIN_ROOT_PATTERN then :win 
        when File.expand_path(".")[0] == ?/ then :nix
        else :unknown
        end
      end
    
      # Returns true if the input path appears to be an expanded path, based on
      # path_root_type.  
      #
      # If root_type == :win returns true if the path matches WIN_ROOT_PATTERN.
      #
      #   expanded?('C:/path')  # => true
      #   expanded?('c:/path')  # => true
      #   expanded?('D:/path')  # => true
      #   expanded?('path')     # => false
      #
      # If root_type == :nix, then expanded? returns true if the path begins
      # with '/'.
      #
      #   expanded?('/path')  # => true
      #   expanded?('path')   # => false
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
    
      # Returns true if path is relative to dir.  Both path and dir will be
      # expanded relative to dir_string, if specified.
      def relative?(dir, path, dir_string=Dir.pwd)
        if dir_string
          dir = File.expand_path(dir, dir_string)
          path = File.expand_path(path, dir_string)
        end
      
        path.rindex(dir, 0) == 0
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
    
      # Returns the path segments for the given path, splitting along the path 
      # divider.  Env paths are always represented by a string, if only an 
      # empty string.
      #
      #   os          divider    example
      #   windows     '\'        split('C:\path\to\file')  # => ["C:", "path", "to", "file"]
      #   *nix        '/'        split('/path/to/file')    # => ["", "path", "to", "file"]
      # 
      # The path is always expanded relative to the expand_dir; so '.' and
      # '..' are resolved.  However, unless expand_path == true, only the
      # segments relative to the expand_dir are returned.  
      #
      # On windows (note that expanding paths allows the use of slashes or
      # backslashes):
      #
      #   Dir.pwd                                          # => 'C:/'
      #   split('path\to\..\.\to\file')                    # => ["C:", "path", "to", "file"]
      #   split('path/to/.././to/file', false)             # => ["path", "to", "file"]
      #
      # On *nix (or more generally systems with '/' roots):
      #
      #   Dir.pwd                                          # => '/'
      #   split('path/to/.././to/file')                    # => ["", "path", "to", "file"]
      #   split('path/to/.././to/file', false)             # => ["path", "to", "file"]
      #
      def split(path, expand_path=true, expand_dir=Dir.pwd)
        path = if expand_path
          File.expand_path(path, expand_dir)
        else
          # normalize the path by expanding it, then
          # work back to the relative path as needed
          expanded_dir = File.expand_path(expand_dir)
          expanded_path = File.expand_path(path, expand_dir)
          expanded_path.index(expanded_dir) != 0 ? expanded_path : relative_path(expanded_dir, expanded_path)
        end

        segments = path.scan(/[^\/]+/)

        # add back the root path as needed on *nix 
        segments.unshift "" if path[0] == ?/
        segments
      end
    
    end
  end
end