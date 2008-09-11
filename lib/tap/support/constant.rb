require 'tap/support/constant_utils'
class String # :nodoc:
  include Tap::Support::ConstantUtils
end

module Tap
  module Support
    class Constant
      
      # The camelized name for self.
      attr_reader :name
      
      # The path to load to initialize the constant name.
      attr_reader :require_path
  
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
  
      # Returns the document for require_path, if set, or nil otherwise.
      def document
        require_path ? Support::Lazydoc[require_path] : nil 
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
      # requires require_path and tries again.  Raises an
      # NameError if the constant cannot be found.
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