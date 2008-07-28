module Tap
  module Support
  
    # FrameworkMethods encapsulates class methods related to Framework.
    module FrameworkMethods
       
      # Returns the default name for the class: to_s.underscore
      attr_accessor :default_name
           
      def self.extended(base)
        caller.each_with_index do |line, index|
          case line
          when /\/framework.rb/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            base.instance_variable_set(:@source_file, File.expand_path($1))
            break
          end
        end
        
        base.instance_variable_set(:@default_name, base.to_s.underscore)
      end
      
      def inherited(child)
        unless child.instance_variable_defined?(:@source_file)
          caller.first =~ /^(([A-z]:)?[^:]+):(\d+)/
          child.instance_variable_set(:@source_file, File.expand_path($1)) 
        end
        
        child.instance_variable_set(:@default_name, child.to_s.underscore)
        super
      end

      def subclass(const_name, configs={}, block_method=:process, &block)
        # Generate the nesting module
        current, constants = const_name.to_s.constants_split
        raise ArgumentError, "#{current} is already defined!" if constants.empty?
         
        subclass_const = constants.pop
        constants.each {|const| current = current.const_set(const, Module.new)}
        
        # Generate the subclass
        subclass = Class.new(self)
        case configs
        when Hash
          subclass.send(:attr_accessor, *configs.keys)
          configs.each_pair do |key, value|
            subclass.configurations.add(key, value)
          end
        when Array
          configs.each do |method, key, value, options, config_block| 
            subclass.send(method, key, value, options, &config_block)
          end
        end
        
        subclass.send(:define_method, block_method, &block)
        subclass.default_name = const_name
        
        caller.each_with_index do |line, index|
          case line
          when /\/tap\/declarations.rb/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            subclass.source_file = File.expand_path($1)
            subclass.lazydoc["#{current}::#{subclass_const}", false]['manifest'] = subclass.lazydoc.register($3.to_i - 1)
            break
          end
        end
        
        # Set the subclass constant
        current.const_set(subclass_const, subclass)
      end
    end
  end
end