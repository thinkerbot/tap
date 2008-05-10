autoload(:GetOptLong, 'getoptlong')

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')

    # ClassConfiguration tracks and handles the class configurations defined in a Tap::Task
    # (or more generally any class that includes with Tap::Support::Configurable).  Each
    # configuration consists of a name, an unprocessed_default value, a default value, and
    # optionally a processing block.  
    #
    # Some metadata is also stored, including the order in which the configurations are 
    # declared.  The metadata allows the creation of more user-friendly configuration files 
    # and facilitates incorporation into command-line applications.
    #
    # See Tap::Support::Configurable for examples of usage.
    # 
    class ClassConfiguration
      include Enumerable
      
      # The class receiving the configurations
      attr_reader :receiver
      
      # A hash of the unprocessed default values
      attr_reader :unprocessed_default
      
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
      
      # A hash of the processed default values.  
      #
      # If duplicate is true, then a 'deep' duplicate of the default values
      # is returned.  In this case, the return will be a new hash, with all 
      # Array and Hash values duplicated.  This can be useful to prevent
      # accidental modification of default values.
      def default(duplicate=false)
        return @default unless duplicate
        
        config = {}
        @default.each do |key, value|
          config[key] = case value
          when Array, Hash then value.dup
          else value
          end
        end
        config
      end
      
      # Returns true if the normalized key is assigned in assignments.
      #
      # Note: as a result of this definition, an existing config must 
      # be removed with unassign == true to make has_config? false.
      def has_config?(key)
        key = normalize_key(key)
        assignments.assigned?(key)
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
      # Yields newly added keys to the block, if given.
      def merge!(another)
        unless another.kind_of?(ClassConfiguration)
          raise ArgumentError.new("cannot convert #{another.class} to ClassConfiguration")
        end
        
        # check each merged key is either unassigned
        # or unassigned to the same receiver as in self
        new_assignments = []
        another.assignments.each do |receiver, key|
          key = normalize_key(key)
          
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
          yield(key) if block_given?
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
        block = process_blocks[normalize_key(key)]
        block ? block.call(value) : value
      end
      
      # Calls block once for each [receiver, key] pair in self, passing those 
      # elements as parameters.
      def each
        assignments.each do |receiver, key|
          yield(receiver, key)
        end
      end
      
      # The path to the :doc template (see format_str)
      DOC_TEMPLATE_PATH = File.expand_path File.dirname(__FILE__) + "/../generator/generators/config/templates/doc.erb"
      
      # The path to the :nodoc template (see format_str)
      NODOC_TEMPLATE_PATH = File.expand_path File.dirname(__FILE__) + "/../generator/generators/config/templates/nodoc.erb"

      # Formats the configurations using the specified template.  Two default
      # templates are defined, :doc and :nodoc.  These map to the contents of
      # DOC_TEMPLATE_PATH and NODOC_TEMPLATE_PATH and correspond to the 
      # documented and undocumented config generator templates.
      #
      # == Custom Templates
      #
      # format_str initializes a Tap::Support::Templater which formats each 
      # [receiver, configurations] pair in turn, and puts the output to the 
      # target using '<<'.   The templater is assigned the following 
      # attributes for use in formatting:
      #
      # receiver:: The receiver
      # class_doc:: The TDoc for the receiver, from Tap::Support::TDoc[receiver]
      # configurations:: An array of attributes for each configuration.  The attributes
      #                  are: [name, default, unprocessed_default, comment]
      # 
      # In the template these can be accessed as any ERB locals, for example:
      #
      #   <%= receiver.to_s %>
      #   <% configurations.each do |name, default, unprocessed_default, comment| %>
      #   ...
      #   <% end %>
      #
      # The input template may be a String or an ERB; either may be used to 
      # initialize the templater.
      def format_str(template=:doc, target="")
        template = case template
        when :doc then File.read(DOC_TEMPLATE_PATH)
        when :nodoc then File.read(NODOC_TEMPLATE_PATH)
        else template
        end
        
        templater = Templater.new(template)  
        assignments.each_pair do |receiver, keys|
          
          # do not consider keys that have been removed
          keys = keys.delete_if {|key| !self.default.has_key?(key) }
          next if keys.empty?
          
          # set the template attributes
          templater.receiver = receiver
          templater.class_doc = Tap::Support::TDoc[receiver]
          
          configuration_doc = templater.class_doc ? templater.class_doc.configurations : nil
          templater.configurations = keys.collect do |key|
            name = key.to_s
            config_attr = if configuration_doc
              configuration_doc.find {|config| config.name == name }   
            else
              Tap::Support::TDoc::ConfigAttr.new("", name, nil, "")
            end
            
            [name, default[key], unprocessed_default[key], config_attr.comment(false)]
          end
          
          target << templater.build
        end
        
        target
      end
      
    end
  end
end