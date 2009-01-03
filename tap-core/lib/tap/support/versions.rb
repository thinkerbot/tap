module Tap
  module Support
    
    # Version provides methods for adding, removing, and incrementing versions
    # at the end of filepaths.  Versions are all formatted like:
    # 'filepath-version.extension'.
    #
    module Versions
      
      # Adds a version to the filepath.  Versioned filepaths follow the format: 
      # 'path-version.extension'.  If no version is specified, then the filepath 
      # is returned.
      #
      #   version("path/to/file.txt", 1.0)            # => "path/to/file-1.0.txt"
      #
      def version(path, version)
        version = version.to_s.strip
        if version.empty? 
          path
        else
          extname = File.extname(path)
          path.chomp(extname) + '-' + version + extname
        end
      end
      
      # Increments the version of the filepath by the specified increment.  
      #
      #   increment("path/to/file-1.0.txt", "0.0.1")  # => "path/to/file-1.0.1.txt"
      #   increment("path/to/file.txt", 1.0)          # => "path/to/file-1.0.txt"
      #
      def increment(path, increment)
        path, version = deversion(path)
        
        # split the version and increment into integer arrays of equal length
        increment, version = [increment, version].collect do |vstr| 
          begin
            vstr.to_s.split(/\./).collect {|v| v.to_i}
          rescue
            raise "Bad version or increment: #{vstr}"
          end
        end
        version.concat Array.new(increment.length - version.length, 0) if increment.length > version.length

        # add the increment to version
        0.upto(version.length-1) do |i|
          version[i] += (increment[i] || 0)
        end

        self.version(path, version.join("."))
      end
      
      # Splits the version from the input path, then returns the path and version.  
      # If no version is specified, then the returned version will be nil.
      #
      #   deversion("path/to/file-1.0.txt")           # => ["path/to/file.txt", "1.0"]
      #   deversion("path/to/file.txt")               # => ["path/to/file.txt", nil]
      #
      def deversion(path)
        extname = File.extname(path)
        extname = '' if extname =~ /^\.\d+$/
        path =~ /^(.*)-(\d(\.?\d)*)#{extname}$/ ? [$1 + extname, $2] : [path, nil]
      end
      
      # A <=> comparison for versions.  compare_versions can take strings, 
      # integers, or even arrays representing the parts of a version.
      #
      #   compare_versions("1.0.0", "0.9.9")          # => 1
      #   compare_versions(1.1, 1.1)                  # => 0
      #   compare_versions([0,9], [0,9,1])            # => -1
      def compare_versions(a,b)
        a, b = [a,b].collect {|item| to_integer_array(item) }
        
        # equalize the lengths of the integer arrays
        d = b.length - a.length
        case 
        when d < 0 then b.concat Array.new(-d, 0)
        when d > 0 then a.concat Array.new(d, 0)
        end 
      
        a <=> b
      end
      
      # Version unique.  Select the latest or earliest versions of each file
      # in the array.  For paths that have no version, vniq considers any
      # version to beat no version.  The order of paths is preserved by
      # default, but the extra sort doing so may be turned off.
      #
      #   paths = [
      #    "/path/to/two-0.0.1.txt",
      #    "/path/to/one-0.0.1.txt",
      #    "/path/to/one.txt",
      #    "/path/to/two-1.0.1.txt",
      #    "/path/to/three.txt"]
      #
      #   vniq(paths)
      #   # => [
      #   # "/path/to/one-0.0.1.txt",
      #   # "/path/to/two-1.0.1.txt",
      #   # "/path/to/three.txt"]
      #
      def vniq(array, earliest=false, preserve_order=true)
        unique = {}
        array.sort.each do |path|
          base, version = deversion(path)
          (unique[base] ||= []) << version
        end
        
        results = []
        unique.each_pair do |base, versions|
          versions = versions.sort {|a, b| compare_versions(a,b) }
          winner = earliest ? versions.shift : versions.pop
          results << version(base, winner)
        end
        
        results = results.sort_by do |path|
          array.index(path)
        end if preserve_order
        
        results
      end
      
      private
      
      # Converts an input argument (typically a string or an array) 
      # to an array of integers.  Splits version string on "."
      def to_integer_array(arg)
        arr = case arg
        when Array then arg
        else arg.to_s.split('.')
        end
        arr.collect {|i| i.to_i}
      end
      
    end
  end
end