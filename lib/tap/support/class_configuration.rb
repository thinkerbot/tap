require 'tap/support/assignments'
require 'tap/support/instance_configuration'

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')

    # ClassConfiguration tracks and handles the class configurations defined in a Tap::Task
    # (or more generally any class that includes with Tap::Support::Configurable).  Each
    # configuration consists of a name, which maps configurations to instance methods, and
    # a default value used to initialize instance configurations.  
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
      
      # A hash of the default values
      attr_reader :default
      
      # Tracks the assignment of the config keys to receivers
      attr_reader :assignments
      
      # A map of config keys and instance methods used to set a 
      # config (ie the getter and setter for a config)
      attr_reader :map

      # A placeholder to indicate when no value 
      # was specified during a call to add. 
      NO_VALUE = Object.new
    
      def initialize(receiver, parent=nil)
        @receiver = receiver
        
        if parent != nil
          @default = parent.default.dup
          @map = parent.map.dup
          @assignments = Assignments.new(parent.assignments)
        else
          @default = {}
          @map = {}
          @assignments = Assignments.new
        end
      end
      
      # Adds or overrides a configuration. If a configuration is added without 
      # specifying a value and no previous default value exists, then nil is 
      # used as the value.  Configuration keys are symbolized.
      #
      #   c = ClassConfiguration.new Object
      #   c.add(:a, 'default')
      #   c.add('b')
      #   c.default     # => {:a => 'default', :b => nil}
      #
      def add(key, value=NO_VALUE)
        key = key.to_sym
        
        assignments.assign(receiver, key) unless assignments.assigned?(key)
        map[key] = "#{key}=".to_sym
        default[key] = (value == NO_VALUE ? default[key] : value)

        self
      end
      
      # Removes the specified configuration.  The key will not
      # be unassigned from it's existing receiver unless specified.
      def remove(key, unassign=false)
        key = key.to_sym
        
        default.delete(key)
        map.delete(key)
        assignments.unassign(key) if unassign

        self
      end
      
      # Returns true if key is a config key.  The key will be 
      # symbolized if specified.
      def key?(key, symbolize=true)
        symbolize ? map.has_key?(key.to_sym) : map.has_key?(key)
      end
      
      # Returns all config keys.
      def keys
        map.keys
      end
      
      # Returns config keys in order.
      def ordered_keys
        assignments.values.select {|key| map.has_key?(key) }
      end
      
      # Returns the setter method for the specified key.
      # Raises an error if the key is not a config.
      def setter(key)
        map[key] or raise(ArgumentError.new("not a config key"))
      end
      
      # Returns the default config value.  If duplicate is true, then 
      # all duplicable values will be duplicated (so that modifications
      # to them will not affect the original default value).  Raises
      # an error if the key is not a config.
      def default_value(key, duplicate=true)
        raise ArgumentError.new("not a config key") unless key?(key)
        
        value = default[key]
        duplicate ? duplicate_value(value) : value
      end
      
      # Calls block once for each [receiver, key] pair in self, 
      # passing those elements as parameters, in the order in
      # which they were assigned.
      def each_assignment
        assignments.each do |receiver, key|
          yield(receiver, key)
        end
      end
      
      # Calls block once for each [getter, setter] pair in self, 
      # passing those elements as parameters, in the order in
      # which they were assigned.
      def each_map
        assignments.each do |receiver, key|
          setter = map[key]
          yield(key, setter) if setter
        end
      end
      
      # Initializes and returns a new InstanceConfiguration bound to self,
      # set with the default values for self (duplicated). 
      def instance_config
        config = InstanceConfiguration.new(self)
        default.each_pair do |key, value|
          config[key] = duplicate_value(value)
        end
        config
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
      #                  are: [name, default, comment]
      # 
      # In the template these can be accessed as any ERB locals, for example:
      #
      #   <%= receiver.to_s %>
      #   <% configurations.each do |name, default, comment| %>
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
      
      protected
      
      # Duplicates the specified value, if the value is duplicable.
      def duplicate_value(value) # :nodoc:
        case value
        when nil, true, false, Symbol, Numeric then value
        else value.dup
        end
      end
    end
  end
end

