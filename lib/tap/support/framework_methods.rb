require 'tap/support/command_line'

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
      
      DEFAULT_HELP_TEMPLATE = %Q{<%= task_class %><%= manifest.subject.to_s.strip.empty? ? '' : ' -- ' %><%= manifest.subject %>

<% unless manifest.empty? %>
<%= '-' * 80 %>

<% manifest.wrap(77, 2, nil).each do |line| %>
  <%= line %>
<% end %>
<%= '-' * 80 %>
<% end %>

}

      def instantiate(argv, app=Tap::App.instance) # => instance, argv
        opts = OptionParser.new
 
        # Add configurations
        config = {}
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end

        configurations.each do |receiver, key, configuration|
          opts.on(*CommandLine.configv(configuration)) do |value|
            config[key] = value
          end
        end

        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"

        opts.on_tail("-h", "--help", "Print this help") do
          args = lazydoc(true)[to_s]['args'] || Tap::Support::Comment.new

          opts.banner = "#{help}usage: tap run -- #{to_s.underscore} #{args.subject}"
          puts opts
          exit
        end

        # Add option for name
        name = default_name
        opts.on_tail('--name NAME', /^[^-].*/, 'Specify a name') do |value|
          name = value
        end

        # Add option to add args
        use_args = []
        opts.on_tail('--use FILE', /^[^-].*/, 'Loads inputs from file') do |value|
          obj = YAML.load_file(value)
          case obj
          when Hash 
            obj.values.each do |value|
              # error if value isn't an array
              use_args.concat(value)
            end
          when Array 
            use_args.concat(obj)
          else
            use_args << obj
          end
        end

        opts.parse!(argv)
        obj = new({}, name, app)

        path_configs = app.load_config(app.config_filepath(name))
        if path_configs.kind_of?(Array)
          path_configs.each_with_index do |path_config, i|
            obj.initialize_batch_obj(path_config, "#{name}_#{i}") unless i == 0
          end
          path_configs = path_configs[0]
        end

        [obj.reconfigure(path_configs).reconfigure(config), argv + use_args]
      end
      
      def lazydoc(resolve=false)
        if resolve
          lazydoc = super(false)
          lazydoc.resolve(nil, /^\s*def\s+process(\((.*?)\))?/) do |comment, match|
            comment.subject = match[2].to_s.split(',').collect do |arg|
              arg = arg.strip.upcase
              case arg
              when /^&/ then nil
              when /^\*/ then arg[1..-1] + "..."
              else arg
              end
            end.join(', ')

            lazydoc.default_attributes['args'] ||= comment
          end
        end
        
        super
      end
      
      def help
        Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, 
          :task_class => self, 
          :manifest => lazydoc(true)[to_s]['manifest'] || Tap::Support::Comment.new
        ).build
      end
    end
  end
end