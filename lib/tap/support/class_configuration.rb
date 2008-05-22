require 'tap/support/assignments'
require 'tap/support/instance_configuration'
require 'tap/support/configuration'

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
          @map = parent.map.inject({}) do |hash, (key, config)|
            hash[key] = config.dup
            hash
          end
          @assignments = Assignments.new(parent.assignments)
        else
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
      def add(key, properties={})
        (self[key] ||= Configuration.new(key)).update(properties)
        self
      end
      
      # Removes the specified configuration.
      def remove(key)
        self[key] = nil
        self
      end
      
      def [](key)
        map[key.to_sym]  
      end
      
      def []=(key, config)
        key = key.to_sym
        
        if config == nil
          map.delete(key)
          assignments.unassign(key)
        else
          assignments.assign(receiver, key) unless assignments.assigned?(key)
          map[key] = config
        end
      end
      
      # Returns true if key is a config key.
      def key?(key)
        map.has_key?(key)
      end
      
      # Returns all config keys.
      def keys
        map.keys
      end
      
      # Returns config keys in order.
      def ordered_keys
        assignments.values
      end

      def values 
        map.values
      end
      
      # Calls block once for each [receiver, key, config] in self, 
      # passing those elements as parameters, in the order in
      # which they were assigned.  
      def each
        assignments.each do |receiver, key|
          yield(receiver, key, map[key])
        end
      end
      
      # Calls block once for each [key, config] pair in self, 
      # passing those elements as parameters, in the order in
      # which they were assigned.
      def each_pair
        assignments.each do |receiver, key|
          config = map[key]
          yield(key, config) if config
        end
      end
      
      # def freeze_configs
      #   @map.each_pair do |key, config|
      #     config.freeze
      #   end
      #   @map.freeze
      #   @assignments.freeze
      # end
      # 
      # def unfreeze_configs
      #   @map = map.inject({}) do |hash, (key, config)|
      #     hash[key] = config.dup
      #     hash
      #   end 
      #   @assignments = @assignments.dup
      # end
      
      # Initializes and returns a new InstanceConfiguration set to self 
      # and bound to the receiver, if specified.
      def instance_config(receiver=nil)
        InstanceConfiguration.new(self, receiver)
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
      # configurations:: An array of configurations and associated comments
      # 
      # In the template these can be accessed as any ERB locals, for example:
      #
      #   <%= receiver.to_s %>
      #   <% configurations.each do |key, config, comment| %>
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
            
            [key, map[key], config_attr.comment(false)]
          end
          
          target << templater.build
        end
        
        target
      end
      
    end
  end
end

