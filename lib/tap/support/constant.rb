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
        
        # constantize tries to find a declared constant with the name specified 
        # by self. Raises a NameError when the name is not in CamelCase 
        # or is not initialized.  
        def constantize(const_name)
          normalize(const_name).split("::").inject(Object) do |current, const|
            const = const.to_sym
            unless const_is_defined?(current, const)
              raise NameError.new("uninitialized constant #{const_name}", const) 
            end
            current.const_get(const)
          end
        end
        
        # Tries to constantize self; if a NameError is raised, try_constantize
        # passes control to the block.  Control is only passed if the NameError
        # is for one of the constants in self.
        def try_constantize(const_name)
          begin
            constantize(const_name)
          rescue(NameError)
            error_name = $!.name.to_s
            
            normal_const_name = normalize(const_name)
            missing_const = normal_const_name.split(/::/).inject(Object) do |current, const|
              if const_is_defined?(current, const)
                current.const_get(const) 
              else 
                break(const)
              end
            end

            # check that the error_name is the first missing constant
            raise $! unless missing_const == error_name
            yield(normal_const_name)
          end
        end
        
        def split(str)
          camel_cased_word = str.camelize
          unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
            raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
          end

          constants = $1.split(/::/)
          current = Object
          while !constants.empty?
            break unless const_is_defined?(current, constants[0])
            current = current.const_get(constants.shift)
          end

          [current, constants]
        end
        
        def normalize(const_name)
          unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ const_name
            raise NameError, "#{const_name.inspect} is not a valid constant name!"
          end
          $1
        end
        
        private
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
        Constant.try_constantize(name) do |const_name|
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