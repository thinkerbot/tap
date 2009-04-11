require 'tap/support/string_ext'

module Tap
  class Env
  
    # A Constant serves as a placeholder for an actual constant, sort of like 
    # autoload.  Use the constantize method to retrieve the actual constant; if
    # it doesn't exist, constantize requires require_path and tries again.
    #
    #   Object.const_defined?(:Net)                      # => false
    #   $".include?('net/http')                          # => false
    #
    #   http = Constant.new('Net::HTTP', 'net/http.rb')
    #   http.constantize                                 # => Net::HTTP
    #   $".include?('net/http.rb')                       # => true
    #
    # === Unloading
    #
    # Constant also supports constant unloading.  Unloading can be useful in
    # various development modes, but make cause code to behave unpredictably.
    # When a Constant unloads, the constant value is detached from the nesting
    # constant and the require path is removed from $".  This allows a require
    # statement to re-require, and in theory, reload the constant.
    #
    #   # [simple.rb]
    #   # class Simple
    #   # end
    #
    #   const = Constant.new('Simple', 'simple')
    #   const.constantize                                # => Simple
    #   Object.const_defined?(:Simple)                   # => true
    #
    #   const.unload                                     # => Simple
    #   Object.const_defined?(:Simple)                   # => false
    #
    #   const.constantize                                # => Simple
    #   Object.const_defined?(:Simple)                   # => true
    #  
    # Unloading and reloading works best for scripts that have no side effects;
    # ie scripts that do not require other files and only define the specified
    # class or module.
    class Constant
      class << self
      
        # Constantize tries to look up the specified constant under const. A
        # block may be given to manually look up missing constants; the last
        # existing const and any non-existant constant names are yielded to the
        # block, which is expected to return the desired constant.  For instance
        # in the example 'Non::Existant' is essentially mapping to ConstName.
        #
        #   module ConstName; end
        #
        #   Constant.constantize('ConstName')                     # => ConstName
        #   Constant.constantize('Non::Existant') { ConstName }   # => ConstName
        #
        # Raises a NameError for invalid/missing constants.
        def constantize(const_name, const=Object) # :yields: const, missing_const_names
          unless CONST_REGEXP =~ const_name
            raise NameError, "#{const_name.inspect} is not a valid constant name!"
          end
        
          constants = $1.split(/::/)
          while !constants.empty?
            unless const_is_defined?(const, constants[0])
              if block_given? 
                return yield(const, constants)
              else
                raise NameError.new("uninitialized constant #{const_name}", constants[0]) 
              end
            end
            const = const.const_get(constants.shift)
          end
          const
        end
      
        private
      
        # helper method.  Determines if the named constant is defined in const.
        # The implementation (annoyingly) has to be different for ruby 1.9 due
        # to changes in the API.
        case RUBY_VERSION
        when /^1.9/
          def const_is_defined?(const, const_name) # :nodoc:
            const.const_defined?(const_name, false)
          end
        else
          def const_is_defined?(const, const_name) # :nodoc:
            const.const_defined?(const_name)
          end
        end
      end
    
      # Matches a valid constant
      CONST_REGEXP = /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/
    
      # The nested constant name
      attr_reader :const_name
    
      # The path to load to initialize a missing constant
      attr_reader :require_path
    
      # An optional comment
      attr_reader :comment
    
      # Initializes a new Constant with the specified constant name,
      # require_path, and comment.  The const_name should be a valid
      # constant name.
      def initialize(const_name, require_path=nil, comment=nil)
        @const_name = const_name
        @require_path = require_path
        @comment = comment
      end
    
      # Returns the underscored const_name.
      #
      #   Constant.new("Const::Name").path           # => 'const/name'
      #
      def path
        @path ||= const_name.underscore
      end
    
      # Returns the basename of path.
      #
      #   Constant.new("Const::Name").basename       # => 'name'
      #
      def basename
        @basename ||= File.basename(path)
      end
    
      # Returns the path, minus the basename of path.
      #
      #   Constant.new("Const::Name").dirname        # => 'const'
      #
      def dirname
        @dirname ||= (dirname = File.dirname(path)) == "." ? "" : dirname
      end
    
      # Returns the name of the constant, minus nesting.
      #
      #   Constant.new("Const::Name").name           # => 'Name'
      #
      def name
        @name ||= (const_name =~ /.*::(.*)\z/ ? $1 : const_name)
      end
    
      # Returns the nesting constant of const_name.
      #
      #   Constant.new("Const::Name").nesting        # => 'Const'
      #
      def nesting
        @nesting ||= (const_name =~ /(.*)::.*\z/ ? $1 : '')
      end
    
      # Returns the number of constants in nesting.
      #
      #   Constant.new("Const::Name").nesting_depth  # => 1
      #
      def nesting_depth
        @nesting_depth ||= nesting.split(/::/).length
      end

      # Returns the Lazydoc document for require_path.
      def document
        require_path ? Lazydoc[require_path] : nil 
      end
    
      # True if another is a Constant with the same const_name,
      # require_path, and comment as self.
      def ==(another)
        another.kind_of?(Constant) && 
        another.const_name == self.const_name &&
        another.require_path == self.require_path &&
        another.comment == self.comment
      end
    
      # Looks up and returns the constant indicated by const_name. If the
      # constant cannot be found, constantize requires require_path and
      # tries again.
      #
      # Raises a NameError if the constant cannot be found.
      def constantize
        Constant.constantize(const_name) do
          require require_path if require_path
          Constant.constantize(const_name)
        end
      end
    
      # Undefines the constant indicated by const_name.  The nesting constants
      # are not removed.  If specified, require_path will be removed from $".
      #
      # When removing require_path, unload will add '.rb' to the require_path if
      # require_path has no extension (this echos the behavior of require).
      # Other extension names like '.so', '.dll', etc. are not tried and will
      # not be removed.
      #
      # Does nothing if const_name doesn't exist.  Returns the unloaded constant.
      # Obviously, <em>this method should be used with caution</em>.
      def unload(unrequire=true)
        const = nesting.empty? ? Object : Constant.constantize(nesting) { Object }
      
        if const.const_defined?(name)
          if unrequire && require_path
            path = File.extname(require_path).empty? ? "#{require_path}.rb" : require_path
            $".delete(path)
          end
        
          return const.send(:remove_const, name)
        end
      
        nil
      end
    
      # Returns a string like:
      #
      #   "#<Tap::Env::Constant:object_id Const::Name (require_path)>"
      #
      def inspect
        "#<#{self.class}:#{object_id} #{const_name}#{@require_path == nil ? "" : " (#{@require_path})"}>"
      end
    end
  end
end