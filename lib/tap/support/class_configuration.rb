autoload(:GetOptLong, 'getoptlong')

module Tap
  module Support
    # == UNDER CONSTRUCTION
    #--
    #
    # ClassConfiguration holds the class configurations defined in a Tap::Task.
    # The configurations are stored as an array of declarations_array like:
    # [name, default, msg, declaration_class].  In addition, ClassConfiguration
    # collapse the array of declarations_array into a hash, which acts as the default
    # task configuration.
    #
    # Storing metadata about the configurations, such as the declaration_class, 
    # allows the creation of more user-friendly configuration files and facilitates 
    # incorporation into command-line applications.
    #
    # In general, users will not have to interact with ClassConfigurations directly.
    #
    # === Example
    # 
    #   class BaseTask < Tap::Configurable
    #     class_configurations [:one, 1]
    #   end
    #
    #   BaseTask.configurations.hash    # => {:one => 1}
    #
    #   class SubTask < BaseTask
    #     class_configurations(
    #       [:one, 'one', "the first configuration"],
    #       [:two, 'two', "the second configuration"])
    #   end
    #
    #   SubTask.configurations.hash    # => {:one => 'one', :two => 'two'}
    #   
    # Now you can see how the comments and declaring classes get used in the
    # configuration files.  Note that configuration keys are stringified
    # for clarity (this is ok -- they will be symbolized when loaded by a
    # task).
    #
    #   [BaseTask.configurations.format_yaml]
    #   # BaseTask configuration
    #   one: 1        
    #
    #   [SubTask.configurations.format_yaml]
    #   # BaseTask configuration
    #   one: one             # the first configuration
    #
    #   # SubTask configuration
    #   two: two             # the second configuration
    #
    #--
    # TODO -
    # Revisit config formatting... right now it's a bit jacked.
    #++
    class ClassConfiguration
      include Enumerable
      
      # The class receiving the configurations
      attr_reader :receiver
      
      # An array of [receiver, configuration keys] arrays tracking
      # the order in which configurations were declared across all
      # receivers
      attr_reader :declarations_array
      
      # An array of configuration keys declared by self
      attr_reader :declarations
      
      # A hash of the unprocessed default values
      attr_reader :unprocessed_default
      
      # A hash of the processed default values
      attr_reader :default
      
      # A hash of the processing blocks
      attr_reader :process_blocks

      # A placeholder to indicate when no value 
      # was specified during a call to add. 
      NO_VALUE = Object.new
    
      def initialize(receiver, parent=nil)
        @receiver = receiver
        @default = parent != nil ? parent.default.dup : {}
        @unprocessed_default = parent != nil ? parent.unprocessed_default.dup : {}
        @process_blocks = parent != nil ? parent.process_blocks.dup : {}
        
        # use same declarations array?  freeze declarations to ensure order?
        # definitely falls out of order if parents are modfied after initialization
        @declarations_array = parent != nil ? parent.declarations_array.dup : []
        @declarations = []
        declarations_array << [receiver, @declarations] 
      end
      
      # Returns true if the key has been declared by some receiver.
      # Note this is distinct from whether or not a particular config
      # is currently in the default hash.
      def declared?(key)
        key = key.to_sym
        declarations_array.each do |r,array| 
          return true if array.include?(key)
        end
        false
      end
      
      # Returns the class (receiver) that first added the config 
      # indicated by key.
      def declaration_class(key)
        key = key.to_sym
        declarations_array.each do |r,array| 
          return r if array.include?(key)
        end
        nil
      end
      
      # Returns the configurations first declared by the specified receiver.
      def declarations_for(receiver)
        declarations_array.each do |r,array| 
          return array if r == receiver
        end
        nil
      end
      
      # Adds a configuration.  If specified, the value is processed
      # by the process_block and recorded adefault 
      #
      # The existing value and process_block for the
      # configuration will not be overwritten unless specified. However,
      # if a configuration is added without specifying a value and no previous 
      # default value exists, the default and unprocessed_default for the 
      # configuration will be set to nil.
      #
      #--
      # Note -- existing blocks are NOT overwritten unless a new block is provided.
      # This allows overide of the default value in subclasses while preserving the 
      # validation/processing code.
      def add(key, value=NO_VALUE, &process_block)
        key = key.to_sym
        value = unprocessed_default[key] if value == NO_VALUE
        
        declarations << key unless declared?(key)
        process_blocks[key] = process_block if block_given?
        unprocessed_default[key] = value
        default[key] = process(key, value)

        self
      end
      
      def remove(key)
        key = key.to_sym
        
        process_blocks.delete(key)
        unprocessed_default.delete(key)
        default.delete(key)
        
        self
      end
      
      def merge(another)
        # check for conflicts
        another.each do |receiver, key|
          dc = declaration_class(key)
          next if dc == nil || dc == receiver
          
          raise "configuration conflict: #{key} (#{receiver}) already declared by #{dc}"
        end
        
        # add the new configurations
        another.each do |receiver, key|
          # preserve the declarations for receiver
          unless declarations = declarations_for(receiver) 
            declarations = []
            declarations_array << [receiver, declarations] 
          end
          unless declarations.include?(key)
            declarations << key 
            yield(key) if block_given?
          end
          
          add(key, another.unprocessed_default[key], &another.process_blocks[key])
        end
      end
    
      def each # :yields: receiver, key
        declarations_array.each do |receiver, keys|
          keys.each {|key| yield(receiver, key) }
        end
      end
      
      # Sends value to the process block identified by key and returns the result.
      # Returns value if no process block has been set for key.
      def process(key, value)
        block = process_blocks[key.to_sym]
        block ? block.call(value) : value
      end
    
      # Nicely formats the configurations into yaml with messages and
      # declaration class divisions.
      def format_yaml
        lines = []
        declarations_array.each do |receiver, keys|
          
          # do not consider keys that have been removed
          keys = keys.delete_if {|key| !self.default.has_key?(key) }
          next if keys.empty?
          
          lines << "# #{receiver} configuration#{keys.length > 1 ? 's' : ''}"
          
          class_doc = Tap::Support::TDoc[receiver]
          configurations = (class_doc == nil ? [] : class_doc.configurations)
          keys.each do |key|
            tdoc_config = configurations.find {|config| config.name == key.to_s }
 
            # yaml adds a header and a final newline which should be removed:
            #   {'key' => 'value'}.to_yaml           # => "--- \nkey: value\n"
            #   {'key' => 'value'}.to_yaml[5...-1]   # => "key: value"
            yaml = {key.to_s => unprocessed_default[key]}.to_yaml[5...-1]
            message = tdoc_config ? tdoc_config.comment : ""
            
            lines << case 
            when message == nil || message.empty?  
              # if there is no message, simply add the yaml
              yaml
            when yaml !~ /\r?\n/ && message !~ /\r?\n/ && yaml.length < 25 && message.length < 30
              # shorthand ONLY if the config and message can be expressed in a single line
              message = message.gsub(/^#\s*/, "")
              "%-25s # %s" % [yaml, message]
            else
              lines << ""
              # comment out new lines and add the message
              message.split(/\n/).each do |msg|
                lines << "# #{msg.strip.gsub(/^#\s*/, '')}"
              end
              yaml
            end
          end
        
          # add a spacer line
          lines << ""
        end
      
        lines.compact.join("\n")
      end
    
      def opt_map(long_option)
        raise ArgumentError.new("not a long option: #{long_option}") unless long_option =~ /^--(.*)$/
        long = $1
      
        each do |receiver, key|
          return key if long == key.to_s
        end  
        nil
      end
    
      def to_opts
        collect do |receiver, key|
          # Note the receiver is used as a placeholder for desc,
          # to be resolved using TDoc.
          attributes = {
            :long => key,
            :short => nil,
            :opt_type => GetoptLong::REQUIRED_ARGUMENT,
            :desc => receiver  
          }

          long = attributes[:long]
          attributes[:long] = "--#{long}" unless long =~ /^-{2}/

          short = attributes[:short].to_s
          attributes[:short] = "-#{short}" unless short.empty? || short =~ /^-/

          [attributes[:long], attributes[:short], attributes[:opt_type], attributes[:desc]]
        end  
      end
    
    end
  end
end