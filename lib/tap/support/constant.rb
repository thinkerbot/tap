require 'tap/support/string_ext'

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
      class << self
        
        # Tries to find a declared constant under base with the specified
        # const_name.  When a constant is missing, constantize yields
        # the current base and any non-existant constant names the block,
        # if given, or raises a NameError.  The block is expected 
        # to return the proper constant.
        #
        #   module ConstName; end
        #
        #   Constant.constantize('ConstName')                     # => ConstName
        #   Constant.constantize('Non::Existant') { ConstName }   # => ConstName
        #
        def constantize(const_name, base=Object) # :yields: base, missing_const_names
          constants = arrayify(const_name)
          while !constants.empty?
            unless const_is_defined?(base, constants[0])
              if block_given? 
                return yield(base, constants)
              else
                raise NameError.new("uninitialized constant #{const_name}", constants[0]) 
              end
            end
            base = base.const_get(constants.shift)
          end
          base
        end
        
        private
        
        # helper method. checks a constant name is valid
        # and splits it into an array of constant names.
        def arrayify(const_name) # :nodoc:
          unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ const_name
            raise NameError, "#{const_name.inspect} is not a valid constant name!"
          end
          $1.split(/::/)
        end
        
        # helper method.  Determines if a constant named
        # name is defined in const.  The implementation
        # (annoyingly) has to be different for ruby 1.9
        # due to changes in the API.
        case RUBY_VERSION
        when /^1.9/
          def const_is_defined?(const, name) # :nodoc:
            const.const_defined?(name, false)
          end
        else
          def const_is_defined?(const, name) # :nodoc:
            const.const_defined?(name)
          end
        end
      end
      
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
        Constant.constantize(name) do
          require require_path if require_path
          Constant.constantize(name)
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