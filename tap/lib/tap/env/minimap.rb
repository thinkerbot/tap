module Tap
  class Env
    
    # Minimap adds minimization and search methods to an array of paths.
    # 
    #   paths = %w{
    #     path/to/file-0.1.0.txt 
    #     path/to/file-0.2.0.txt
    #     path/to/another_file.txt
    #   }
    #   paths.extend Env::Minimap
    #
    #   paths.minimatch('file')             # => 'path/to/file-0.1.0.txt'
    #   paths.minimatch('file-0.2.0')       # => 'path/to/file-0.2.0.txt'
    #   paths.minimatch('another_file')     # => 'path/to/another_file.txt'
    #
    # More generally, Minimap may extend any object responding to each.
    # Non-string entries are allowed; if the entry responds to minikey, then
    # minimap will call that method to determine the 'path' to the entry.
    # Otherwise, to_s is used.  Override the entry_to_minikey method to
    # change this default behavior.
    #
    #   class ConstantMap < Array
    #     include Env::Minimap
    #
    #     def entry_to_minikey(const)
    #       const.underscore
    #     end
    #   end 
    #
    #   constants = ConstantMap[Tap::Env::Minimap, Tap::Env]
    #   constants.minimatch('env')          # => Tap::Env
    #   constants.minimatch('minimap')      # => Tap::Env::Minimap
    #
    module Minimap

      # Provides a minimized map of the entries using keys provided minikey.
      #
      #   paths = %w{
      #     path/to/file-0.1.0.txt 
      #     path/to/file-0.2.0.txt
      #     path/to/another_file.txt
      #   }.extend Minimap
      #
      #   paths.minimap
      #   # => [
      #   # ['file-0.1.0',  'path/to/file-0.1.0.txt'],
      #   # ['file-0.2.0',  'path/to/file-0.2.0.txt'],
      #   # ['another_file','path/to/another_file.txt']]
      #
      def minimap
        hash = {}
        map = []
        each {|entry| map << (hash[entry_to_minikey(entry)] = [entry]) }
        minimize(hash.keys) do |key, mini_key|
          hash[key].unshift mini_key
        end
      
        map
      end
    
      # Returns the first entry whose minikey mini-matches the input, or nil if
      # no such entry exists.
      #
      #   paths = %w{
      #     path/to/file-0.1.0.txt 
      #     path/to/file-0.2.0.txt
      #     path/to/another_file.txt
      #   }.extend Minimap
      #
      #   paths.minimatch('file-0.2.0')       # => 'path/to/file-0.2.0.txt'
      #   paths.minimatch('file-0.3.0')       # => nil
      #
      def minimatch(key)
        key = key.to_s
        each do |entry| 
          return entry if minimal_match?(entry_to_minikey(entry), key)
        end
        nil
      end
      
      # Returns minimap as a hash of (minikey, value) pairs.
      def minihash(reverse=false)
        hash = {}
        minimap.each do |key, value|
          if reverse
            hash[value] = key
          else
            hash[key] = value
          end
        end
        hash
      end
    
      protected
    
      # A hook to convert entries to minikeys.  Returns the entry by default, 
      # or entry.minikey if the entry responds to minikey.
      def entry_to_minikey(entry)
        entry.respond_to?(:minikey) ? entry.minikey : entry.to_s
      end
    
      module_function
    
      # Minimizes a set of paths to the set of shortest basepaths that unqiuely 
      # identify the paths.  The path extension and versions are removed from
      # the basepath if possible.  For example:
      #
      #   Minimap.minimize ['path/to/a.rb', 'path/to/b.rb']
      #   # => ['a', 'b']
      #
      #   Minimap.minimize ['path/to/a-0.1.0.rb', 'path/to/b-0.1.0.rb']
      #   # => ['a', 'b']
      #
      #   Minimap.minimize ['path/to/file.rb', 'path/to/file.txt']
      #   # => ['file.rb', 'file.txt']
      #
      #   Minimap.minimize ['path-0.1/to/file.rb', 'path-0.2/to/file.rb']
      #   # => ['path-0.1/to/file', 'path-0.2/to/file']
      #
      # Minimized paths that carry their extension will always carry
      # their version as well, but the converse is not true; paths
      # can be minimized to carry just the version and not the path
      # extension.
      #
      #   Minimap.minimize ['path/to/a-0.1.0.rb', 'path/to/a-0.1.0.txt']
      #   # => ['a-0.1.0.rb', 'a-0.1.0.txt']
      #
      #   Minimap.minimize ['path/to/a-0.1.0.rb', 'path/to/a-0.2.0.rb']
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
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'file')           # => true
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'dir/file')       # => true
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0')     # => true
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0.rb')  # => true
      #
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'file.rb')        # => false
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.2.0')     # => false
      #   Minimap.minimal_match?('dir/file-0.1.0.rb', 'another')        # => false
      #
      # In matching, partial basenames are not allowed but partial directories
      # are allowed.  Hence:
      #
      #   Minimap.minimal_match?('dir/file-0.1.0.txt', 'file')          # => true
      #   Minimap.minimal_match?('dir/file-0.1.0.txt', 'ile')           # => false
      #   Minimap.minimal_match?('dir/file-0.1.0.txt', 'r/file')        # => true
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
  end
end