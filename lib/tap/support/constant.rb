require 'tap/support/constant_utils'

module Tap
  module Support
    
    # A Constant serves as a placeholder for an actual constant, sort of like 
    # autoload.  Use the constantize method to retrieve the actual constant; 
    # if it doesn't exist, constantize requires require_path and tries again.
    #
    #   Object.const_defined?(:Net)                      # => false
    #   $".include?('net/http')                          # => false
    #
    #   http = Constant.new('Net::HTTP', 'net/http')
    #   http.constantize                                 # => Net::HTTP
    #   $".include?('net/http')                          # => true
    #
    class Constant
      
      # The constant name
      attr_reader :name
      
      # The path to load to initialize a missing constant
      attr_reader :require_path
      
      # Initializes a new Constant with the specified constant
      # name and require_path.  The name should be a valid
      # constant name.
      def initialize(name, require_path=nil)
        @name = name
        @require_path = require_path
      end
      
      # Returns the underscored name.
      def path
        @path ||= name.underscore
      end
      
      # Returns the basename of path.
      def basename
        @basename ||= File.basename(path)
      end
      
      # Returns the path, minus the basename of path. 
      def dirname
        @dirname ||= (dirname = File.dirname(path)) == "." ? "" : dirname
      end
      
      # Returns the name of the constant, minus nesting.
      def const_name
        @const_name ||= (name =~ /.*::(.*)$/ ? $1 : name)
      end
      
      # Returns an array of the nesting constants of name.
      def nesting
        @nesting ||= (name =~ /(.*)::.*$/ ? $1 : '')
      end
      
      # Returns the number of constants in nesting.
      def nesting_depth
        @nesting_depth ||= nesting.split(/::/).length
      end
  
      # Returns the Lazydoc document for require_path.
      def document
        require_path ? Lazydoc[require_path] : nil 
      end
      
      # True if another is a Constant with the same name
      # and require_path as self.
      def ==(another)
        another.kind_of?(Constant) && 
        another.name == self.name &&
        another.require_path == self.require_path
      end
      
      # Looks up and returns the constant indicated by name.
      # If the constant cannot be found, the constantize
      # requires require_path and tries again.  
      #
      # Raises a NameError if the constant cannot be found.
      def constantize
        name.try_constantize do |const_name|
          require require_path if require_path
          name.constantize
        end
      end
      
      # Returns a string like:
      #   "#<Tap::Support::Constant:object_id Const::Name (require_path)>"
      def inspect
        "#<#{self.class}:#{object_id} #{name}#{@require_path == nil ? "" : " (#{@require_path})"}>"
      end
    end
  end
end