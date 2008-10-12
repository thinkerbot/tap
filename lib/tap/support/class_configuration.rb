require 'tap/support/assignments'
require 'tap/support/instance_configuration'
require 'tap/support/configuration'

module Tap
  module Support
    
    # ClassConfiguration tracks configurations defined by a Configurable class.
    class ClassConfiguration
      include Enumerable
      
      config_templates_dir = File.expand_path File.dirname(__FILE__) + "/../generator/generators/config/templates"

      # The path to the :doc template (see inspect)
      DOC_TEMPLATE_PATH = File.join(config_templates_dir, 'doc.erb')

      # The path to the :nodoc template (see inspect)
      NODOC_TEMPLATE_PATH = File.join(config_templates_dir, 'nodoc.erb')
      
      # The Configurable class receiving new configurations
      attr_reader :receiver

      # An Assignments tracking the assignment of config keys to receivers
      attr_reader :assignments
      
      # A map of [key, Configuration] pairs
      attr_reader :map
      
      # Generates a new ClassConfiguration for the receiver.  If a parent is 
      # provided, configurations will be inherited from it.
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

      # Initializes a Configuration using the inputs and sets using name 
      # as a key.  Any existing config by the same name is overridden. 
      # Returns the new config.
      def add(name, default=nil, attributes={})
        self[name] = Configuration.new(name.to_sym, default, attributes)
      end
      
      # Removes the specified configuration.
      def remove(key)
        self[key] = nil
      end
      
      # Gets the config specified by key.  The key is symbolized.
      def [](key)
        map[key.to_sym]  
      end
      
      # Assigns the config to key.  A nil config unassigns the
      # configuration key.  The key is symbolized.
      def []=(key, config)
        key = key.to_sym
        
        if config == nil
          assignments.unassign(key)
          map.delete(key)
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
      
      # Returns all mapped configs.
      def values 
        map.values
      end
      
      # True if map is empty.
      def empty?
        map.empty?
      end
      
      # Calls block once for each [receiver, key, config] in self, 
      # passing those elements as parameters in the order in
      # which they were assigned.  
      def each
        assignments.each do |receiver, key|
          yield(receiver, key, map[key])
        end
      end
      
      # Calls block once for each [key, config] pair in self, 
      # passing those elements as parameters in the order in
      # which they were assigned.
      def each_pair
        assignments.each do |receiver, key|
          yield(key, map[key])
        end
      end
      
      # Initializes and returns a new InstanceConfiguration set to self 
      # and bound to the receiver, if specified.
      def instance_config(receiver=nil, store={})
        InstanceConfiguration.new(self, receiver, store)
      end
      
      # Returns a hash of the [key, config.default] pairs in self.
      def to_hash
        hash = {}
        each_pair {|key, config| hash[key] = config.default }
        hash
      end
      
      # An array of config descriptions that are Comment objects.
      def code_comments
        code_comments = []
        values.each do |config| 
          code_comments << config.desc if config.desc.kind_of?(Lazydoc::Comment)
        end
        code_comments
      end
      
      # Inspects the configurations using the specified template.  Templates
      # are used for format each [receiver, configurations] pair in self.
      # See DEFAULT_TEMPLATE as a model.  The results of each template cycle
      # are pushed to target.
      #
      # Two default templates are defined, <tt>:doc</tt> and <tt>:nodoc</tt>.
      # These map to the contents of DOC_TEMPLATE_PATH and NODOC_TEMPLATE_PATH
      # and correspond to the documented and undocumented 
      # Tap::Generator::Generators::ConfigGenerator templates.
      def inspect(template=:doc, target="")
        Lazydoc.resolve_comments(code_comments)
        
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
          templater.configurations = keys.collect do |key|
            # duplicate config so that any changes to it
            # during templation will not propogate back
            # into self
            [key, map[key].dup]
          end.compact
          
          yield(templater) if block_given?
          target << templater.build
        end
        
        target
      end
    end
  end
end

