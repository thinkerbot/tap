require 'tap/support/assignments'
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
      attr_reader :default
      
      # Tracks the assignment of the config keys to receivers
      attr_reader :assignments

      # A placeholder to indicate when no value 
      # was specified during a call to add. 
      NO_VALUE = Object.new
    
      def initialize(receiver, parent=nil)
        @receiver = receiver
        
        if parent != nil
          @default = parent.default.dup
          @assignments = Assignments.new(parent.assignments)
        else
          @default = {}
          @assignments = Assignments.new
        end
      end
      
      def each_default_pair
        default.each_pair do |key, value|
          value = case value
          when Array, Hash then value.dup
          else value
          end
 
          yield(key, value)
        end
      end
      
      # Returns true if the normalized key is assigned in assignments.
      #
      # Note: as a result of this definition, an existing config must 
      # be removed with unassign == true to make has_config? false.
      def has_config?(key)
        assignments.assigned?(key.to_sym)
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
      def add(key, value=NO_VALUE)
        key = key.to_sym
        
        assignments.assign(receiver, key) unless assignments.assigned?(key)
        
        value = default[key] if value == NO_VALUE
        default[key] = value

        self
      end
      
      # Removes the specified configuration.  The key will not
      # be unassigned from it's existing receiver unless specified.
      def remove(key, unassign=false)
        key = key.to_sym
        
        default.delete(key)
        assignments.unassign(key) if unassign

        self
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
            
            [name, default[key], config_attr.comment(false)]
          end
          
          target << templater.build
        end
        
        target
      end
      
    end
  end
end