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
  
      def constantize
        name.try_constantize do |const_name|
          require require_path
          name.constantize
        end
      end
    end
  end
end