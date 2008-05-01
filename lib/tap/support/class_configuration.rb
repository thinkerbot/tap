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
    # for clarity (this is ok -- they will be normalize_keyd when loaded by a
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
      
      # A hash of the unprocessed default values
      attr_reader :unprocessed_default
      
      # A hash of the processed default values
      attr_reader :default
      
      # A hash of the processing blocks
      attr_reader :process_blocks
      
      # The declaration history of the config keys
      attr_reader :declaration_history

      # A placeholder to indicate when no value 
      # was specified during a call to add. 
      NO_VALUE = Object.new
    
      def initialize(receiver, parent=nil)
        @receiver = receiver
        
        if parent != nil
          @default = parent.default.dup
          @unprocessed_default = parent.unprocessed_default.dup
          @process_blocks = parent.process_blocks.dup
          @declaration_history = OrderArray.new(parent.declaration_history)
        else
          @default = {}
          @unprocessed_default = {}
          @process_blocks = {}
          @declaration_history = OrderArray.new
        end
      end
      
      # Normalizes a configuration key by symbolizing.
      def normalize_key(key)
        key.to_sym
      end
      
      def declared?(key)
        declaration_history.values.include?(key)
      end
      
      def declare(key)
        declaration_history.add(receiver, key) unless declared?(key)
      end
      
      # Adds a configuration. The existing value and process_block for the
      # configuration will not be overwritten unless specified. However,
      # if a configuration is added without specifying a value and no previous 
      # default value exists, the default and unprocessed_default for the 
      # configuration will be set to nil. 
      #
      # Configuration keys normalized using normalize_key. New values and 
      # process blocks can always be input to override old settings.
      #
      #   c = ClassConfiguration.new Object
      #   c.add(:config, "1") {|value| value.to_i}
      #   c.add('no_value_specified')
      #   c.default     # => {:config => 1, :no_value_specified => nil}
      #
      #   c.add(:config, "2")
      #   c.add(:no_value_specified, 10) {|value| value.to_s }
      #   c.default     # => {:config => 2, :no_value_specified => "10"}
      #
      #--
      # Note -- existing blocks are NOT overwritten unless a new block is provided.
      # This allows overide of the default value in subclasses while preserving the 
      # validation/processing code.
      def add(key, value=NO_VALUE, &process_block)
        key = normalize_key(key)
        
        value = unprocessed_default[key] if value == NO_VALUE
        
        declare(key)
        process_blocks[key] = process_block if block_given?
        unprocessed_default[key] = value
        default[key] = process(key, value)

        self
      end
      
      # Removes the specified configuration.  The declaration will not be removed
      # unless specified.
      def remove(key, remove_declaration=false)
        key = normalize_key(key)
        
        process_blocks.delete(key)
        unprocessed_default.delete(key)
        default.delete(key)
        declaration_history.remove(key) if remove_declaration

        self
      end
      
      # Merges the configurations of another with self, preserving the declaration
      # history for another.  Raises an error if the declaration class of an existing
      # configuration does not match that of another.
      # def merge(another)
      ########################################################
      # current_values = self.values
      # existing_values, new_values = values.partition {|value| current_values.include?(value) }
      # 
      # conflicts = []
      # existing_values.collect do |value|
      #   current_key = key_for(value)
      #   if current_key != key 
      #     conflicts << "#{value} (#{key}) already declared for #{current_key}"
      #   end
      # end
      # 
      # unless conflicts.empty?
      #   raise ArgumentError.new(conflicts.join("\n"))
      # end
      #######################################################
      #
      #   # check each merged key is either undeclared
      #   # or declared by the same receiver as in self
      #   another_receivers = []
      #   another = another.collect do |receiver, key|
      #     key = normalize_key(key)
      #     
      #     dc = declaration_history.declaration_class(key)
      #     case dc
      #     when nil, receiver 
      #       another_receivers << receiver
      #       [receiver, key]
      #     else
      #       raise "configuration merge conflict: #{key} (#{receiver}) already declared by #{dc}"
      #     end
      #   end
      #   
      #   # add receivers if necessary
      #   (another_receivers - declaration_history.receivers).each do |new_receiver|
      #     declaration_history.add_receiver(new_receiver)
      #   end
      #   
      #   # add the new configurations
      #   another.each do |receiver, key|
      #     if declarations.include?(key)
      #       remove(key)
      #     else
      #       declarations << key
      #     end
      #     
      #     add(key, another.unprocessed_default[key], &another.process_blocks[key])
      #   end
      # end
      

    
      def each # :yields: receiver, key
        declaration_history.each do |receiver, key|
          yield(receiver, key)
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
      def format_yaml(document=true)
        lines = []
        declaration_history.history.each do |receiver, keys|
          
          # do not consider keys that have been removed
          keys = keys.delete_if {|key| !self.default.has_key?(key) }
          next if keys.empty?
          
          lines << "###############################################################################"
          lines << "# #{receiver} configuration#{keys.length > 1 ? 's' : ''}"
          lines << "###############################################################################"

          class_doc = Tap::Support::TDoc[receiver]
          configurations = (class_doc == nil ? [] : class_doc.configurations)
          keys.each do |key|
            tdoc_config = configurations.find {|config| config.name == key.to_s }
 
            # yaml adds a header and a final newline which should be removed:
            #   {'key' => 'value'}.to_yaml           # => "--- \nkey: value\n"
            #   {'key' => 'value'}.to_yaml[5...-1]   # => "key: value"
            yaml = {key.to_s => unprocessed_default[key]}.to_yaml[5...-1]
            yaml = "##{yaml}" if unprocessed_default[key] == nil
            
            message = tdoc_config ? tdoc_config.comment(false) : ""

            if document && !message.empty?
              lines << "" unless lines[-1].empty?
              
              # comment out new lines and add the message
              message.split(/\n/).each do |msg|
                lines << "# #{msg.strip.gsub(/^#\s*/, '')}"
              end
              lines << yaml
              lines << ""
            else
              # if there is no message, simply add the yaml
              lines << yaml
            end
          end
          
          lines << "" # add a spacer
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