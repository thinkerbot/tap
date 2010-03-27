require 'tap/env/string_ext'
require 'tap/root'

module Tap
  class Env
  
    # A Constant serves as a placeholder for an actual constant, sort of like 
    # autoload.  Use the constantize method to retrieve the actual constant; if
    # it doesn't exist, constantize requires require_path and tries again.
    #
    #   Object.const_defined?(:Net)                      # => false
    #   $".grep(/net\/http.rb$/).empty?                  # => true
    #
    #   http = Constant.new('Net::HTTP', 'net/http.rb')
    #   http.constantize                                 # => Net::HTTP
    #   $".grep(/net\/http.rb$/).empty?                  # => false
    #
    # === Unloading
    #
    # Constant also supports constant unloading.  Unloading can be useful in
    # various development modes, but may cause code to behave unpredictably.
    # When a Constant unloads, the constant value is removed from the nesting
    # constant and the require paths are removed from $".  This allows a
    # require statement to re-require, and in theory, reload the constant.
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
    #
    #--
    # ==== Rationale for that last statement
    #
    # Scripts that require other files will not re-require the other files
    # because unload doesn't remove the other files from $".  Likewise scripts
    # that define other constants effectively overwrite the existing constant;
    # that may or may not be a big deal, but it can cause warnings.  Moreover,
    # if a script actually DOES something (like create a file), that something
    # will be repeated when it gets re-required.
    #
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
        
        # Scans the directory and pattern for constants.
        def scan(dir, pattern="**/*.rb")
          constants = {}
          
          root = Root.new(dir)
          root.glob(pattern).each do |path|
            Lazydoc::Document.scan(File.read(path)) do |const_name, type, summary|
              require_path = root.relative_path(path)
              
              if const_name.empty?
                extname = File.extname(path)
                const_name = require_path.chomp(extname).camelize
              end
              
              constant = (constants[const_name] ||= new(const_name))
              constant.register_as(type, summary)
              constant.require_paths << require_path
            end
          end

          constants = constants.values
          constants.each {|constant| constant.require_paths.uniq! }
          constants
        end
        
        def cast(obj)
          case obj
          when String   then new(obj)
          when Module   then new(obj.to_s)
          when Constant then obj
          else raise ArgumentError, "not a constant or constant name: #{obj.inspect}"
          end
        end
      
        private
      
        # helper method.  Determines if the named constant is defined in const.
        # The implementation has to be different for ruby 1.9 due to changes
        # in the API.
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
    
      # Matches a valid constant.  After the match:
      #
      #   $1:: The unqualified constant (ex 'Const' for '::Const')
      #
      CONST_REGEXP = /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/
    
      # The full constant name
      attr_reader :const_name
    
      # An array of paths that will be required when the constantize is called
      # and the constant does not exist.  Require paths are required in order.
      attr_reader :require_paths
      
      # A hash of (type, summary) pairs used to classify self.
      attr_reader :types
    
      # Initializes a new Constant with the specified constant name, and
      # require_paths.  Raises an error if const_name is not valid.
      def initialize(const_name, *require_paths)
        @const_name = normalize(const_name)
        @require_paths = require_paths
        @types = {}
      end
      
      def relative_path
        @relative_path ||= const_name.underscore
      end
    
      # Returns the underscored const_name.
      #
      #   Constant.new("Const::Name").path           # => '/const/name'
      #
      def path
        @path ||= "/#{relative_path}"
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
      #   Constant.new("Const::Name").dirname        # => '/const'
      #
      def dirname
        @dirname ||= File.dirname(path)
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
      
      # True if another is a Constant with the same const_name,
      # require_path, and comment as self.
      def ==(another)
        another.kind_of?(Constant) && 
        another.const_name == self.const_name &&
        another.require_paths == self.require_paths
      end
      
      # Peforms comparison of the const_name of self vs another.
      def <=>(another)
        const_name <=> another.const_name
      end
    
      # Registers the type and summary with self.  Raises an error if self is
      # already registerd as the type and override is false.
      def register_as(type, summary=nil, override=false)
        if types.include?(type) && types[type] != summary && !override
          raise "already registered as a #{type.inspect} (#{const_name})"
        end
        
        types[type] = summary
        self
      end
      
      # Looks up and returns the constant indicated by const_name. If the
      # constant cannot be found, constantize requires the require_paths
      # in order and tries again.
      #
      # Raises a NameError if the constant cannot be found.
      def constantize(autorequire=true)
        Constant.constantize(const_name) do
          break unless autorequire
          
          require_paths.each do |require_path|
            require require_path
          end
          
          Constant.constantize(const_name)
        end
      end
    
      # Undefines the constant indicated by const_name.  The nesting constants
      # are not removed.  If specified, the require_paths will be removed from $".
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
          require_paths.each do |require_path|
            require_path = File.extname(require_path).empty? ? "#{require_path}.rb" : require_path
            regexp = /#{require_path}$/
            
            $".delete_if {|path| path =~ regexp }
          end if unrequire
        
          return const.send(:remove_const, name)
        end
      
        nil
      end
      
      def path_match?(head, tail=nil)
        (head.nil? || head.empty? || head_match(head)) && (tail.nil? || tail.empty? || tail_match(tail))
      end
      
      # Returns a string like:
      #
      #   "#<Tap::Env::Constant:object_id Const::Name (require_path)>"
      #
      def inspect
        "#<#{self.class}:#{object_id} #{const_name} #{require_paths.inspect}>"
      end
      
      # Returns const_name
      def to_s
        const_name
      end
      
      private
      
      def normalize(const_name) # :nodoc:
        case const_name
        when Module       then const_name.to_s
        when CONST_REGEXP then $1
        else raise NameError, "#{const_name.inspect} is not a valid constant name!"
        end
      end
      
      def head_match(head) # :nodoc:
        index = path.index(head)
        index == (head[0] == ?/ ? 0 : 1) && begin
          match_end = index + head.length
          (match_end == path.length || path[match_end] == ?/)
        end
      end
      
      def tail_match(tail) # :nodoc:
        index = path.rindex(tail)
        index && (index + tail.length) == path.length && (index == 0 || path[index-1] == ?/)
      end
    end
  end
end