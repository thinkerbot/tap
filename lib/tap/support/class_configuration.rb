autoload(:GetOptLong, 'getoptlong')

module Tap
  module Support

    # ClassConfiguration tracks and handles the class configurations defined in a Tap::Task
    # (or more generally any class extended with Tap::Support::ConfigurableMethods).  Each
    # configuration consists of a name, an unprocessed_default value, a default value, and
    # optionally a processing block.  
    #
    # Some metadata is also stored, including the order in which the configurations are 
    # declared.  The metadata allows the creation of more user-friendly configuration files 
    # and facilitates incorporation into command-line applications.
    #
    # See Tap::Support::ConfigurableMethods for examples of usage.
    # 
    #--
    # === Example
    # In general ClassConfigurations are only interacted with through ConfigurableMethods.
    # These define attr-like readers/writers/accessors:
    #  
    #   class BaseClass
    #     include Tap::Support::ConfigurableMethods
    #     config :one, 1
    #     config :three, 3
    #   end
    #
    #   BaseClass.configurations.default    # => {:one => 1, :three => 3}
    #
    # ClassConfigurations are inherited and decoupled from the parent.  You
    # may need to interact with configurations directly:
    #
    #   class SubClass < BaseClass
    #     config :one, 'one'
    #     config :two, 'TWO' {|value| value.downcase }
    #
    #     configurations.remove(:three)
    #   end
    #
    #   BaseClass.configurations.default              # => {:one => 1, :three => 3}
    #   SubClass.configurations.default               # => {:one => 'one', :two => 'two'}
    #   SubClass.configurations.unprocessed_default   # => {:one => 'one', :two => 'TWO'}
    #   
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
      
      # Tracks the assignment of the config keys to receivers
      attr_reader :assignments

      # A placeholder to indicate when no value 
      # was specified during a call to add. 
      NO_VALUE = Object.new
    
      def initialize(receiver, parent=nil)
        @receiver = receiver
        
        if parent != nil
          @default = parent.default.dup
          @unprocessed_default = parent.unprocessed_default.dup
          @process_blocks = parent.process_blocks.dup
          @assignments = Assignments.new(parent.assignments)
        else
          @default = {}
          @unprocessed_default = {}
          @process_blocks = {}
          @assignments = Assignments.new
        end
      end
      
      # Normalizes a configuration key by symbolizing.
      def normalize_key(key)
        key.to_sym
      end
      
      # Adds or overrides a configuration. If a configuration is added without 
      # specifying a value and no previous default value exists, then nil is 
      # used as the value.
      #
      # Configuration keys are normalized using normalize_key.  New values and 
      # process blocks can always be input to override old settings; the existing 
      # value and process_block for the configuration will not be overwritten 
      # unless specified, and can be specified independently.
      #
      #   c = ClassConfiguration.new Object
      #   c.add(:a, "1") {|value| value.to_i}
      #   c.add('b')
      #
      #   c.default     # => {:a => 1, :b => nil}
      #
      #   c.add(:a, "2")
      #   c.add(:b, 10) 
      #   c.add(:b) {|value| value.to_s }
      #
      #   c.default     # => {:a => 2, :b => "10"}
      #
      def add(key, value=NO_VALUE, &process_block)
        key = normalize_key(key)
        
        value = unprocessed_default[key] if value == NO_VALUE
        
        assignments.assign(receiver, key) unless assignments.assigned?(key)
        process_blocks[key] = process_block if block_given?
        unprocessed_default[key] = value
        default[key] = process(key, value)

        self
      end
      
      # Removes the specified configuration.  The key will not
      # be unassigned from it's existing receiver unless specified.
      def remove(key, unassign=false)
        key = normalize_key(key)
        
        process_blocks.delete(key)
        unprocessed_default.delete(key)
        default.delete(key)
        assignments.unassign(key) if unassign

        self
      end
      
      # Merges the configurations of another with self.  The values
      # and processing blocks of another override those of self, 
      # when applicable, and the assignments of another are passed on.  
      #
      #   a = ClassConfiguration.new 'ClassOne'
      #   a.add(:one, "one") 
      #
      #   b = ClassConfiguration.new 'ClassTwo'
      #   b.add(:two, "two")
      #
      #   a.merge!(b)
      #   a.default     # => {:one => "one", :two => "two"}
      #
      # An error will be raised if you merge configurations where
      # an existing config is assigned to a different receiver:
      #
      #   c = ClassConfiguration.new 'ClassThree'
      #   c.add(:one)
      #
      #   c.assignments.key_for(:one)   # => 'ClassThree'
      #   a.assignments.key_for(:one)   # => 'ClassOne'
      #
      #   a.merge!(c)                    # !> ArgumentError
      #
      def merge!(another)
        unless another.kind_of?(ClassConfiguration)
          raise ArgumentError.new("cannot convert #{another.class} to ClassConfiguration")
        end
        
        # check each merged key is either unassigned
        # or unassigned to the same receiver as in self
        new_assignments = []
        another.assignments.each do |receiver, key|
          current_receiver = assignments.key_for(key)
          next if current_receiver == receiver
          
          if current_receiver == nil 
            new_assignments << [receiver, key]
          else 
            raise ArgumentError.new("merge conflict: #{key} (#{receiver}) already assigned to #{current_receiver}")
          end
        end
        
        # add the new assignements
        new_assignments.each do |receiver, key|
          assignments.assign(receiver, key)
        end
        
        # merge the new configurations
        another.each do |receiver, key|
          remove(key)
          add(key, another.unprocessed_default[key], &another.process_blocks[key])
        end
      end
      
      # Sends value to the process block identified by key and returns the result.
      # Returns value if no process block has been set for key.
      def process(key, value)
        block = process_blocks[key.to_sym]
        block ? block.call(value) : value
      end
      
      def each # :yields: receiver, key
        assignments.each do |receiver, key|
          yield(receiver, key)
        end
      end
    
      # Nicely formats the configurations into yaml with messages and
      # declaration class divisions.
      def format_yaml(document=true)
        lines = []
        assignments.each_pair do |receiver, keys|
          
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