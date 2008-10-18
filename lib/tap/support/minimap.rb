require 'tap/root'

module Tap
  module Support
    
    # Minimap adds minimization and search methods to an array of paths (see 
    # Tap::Root.minimize and Tap::Root.minimal_match?).
    # 
    #   paths = %w{
    #     path/to/file-0.1.0.txt 
    #     path/to/file-0.2.0.txt
    #     path/to/another_file.txt
    #   }
    #   paths.extend Minimap
    #
    #   paths.minimatch('file')             # => 'path/to/file-0.1.0.txt'
    #   paths.minimatch('file-0.2.0')       # => 'path/to/file-0.2.0.txt'
    #   paths.minimatch('another_file')     # => 'path/to/another_file.txt'
    #
    # More generally, Minimap may extend any object responding to each. 
    # Override the minikey method to convert objects into paths.
    #
    #   class ConstantMap < Array
    #     include Minimap
    #
    #     def minikey(const)
    #       const.underscore
    #     end
    #   end 
    #
    #   constants = ConstantMap[Tap::Support::Minimap Tap::Root]
    #   constants.minimatch('root')         # => Tap::Root
    #   constants.minimatch('minimap')      # => Tap::Support::Minimap
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
        each {|entry| map << (hash[minikey(entry)] = [entry]) }
        Tap::Root.minimize(hash.keys) do |key, mini_key|
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
        each do |entry| 
          return entry if Tap::Root.minimal_match?(minikey(entry), key)
        end
        nil
      end
      
      protected
      
      # A hook to convert a non-path entry into a path for minimap and
      # minimatch.  Returns the entry by default.
      def minikey(entry)
        entry
      end
    end
  end
end