module Tap
  module Support

    # FrameworkMethods encapsulates class methods related to Framework.
    module FrameworkMethods
      
      # ConfigurableMethods initializes base.configurations on extend.
      def self.extended(base)
        caller.each_with_index do |line, index|
          case line
          when /\/framework.rb/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            base.instance_variable_set(:@tdoc, TDoc.instance.document_for($1))
            break
          end
        end
      end
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        caller.first =~ /^(([A-z]:)?[^:]+):(\d+)/
        child.instance_variable_set(:@tdoc, TDoc.instance.document_for($1))
      end
      
      # Returns the default name for the class: to_s.underscore
      def default_name
        @default_name ||= to_s.underscore
      end

      def enq(name=nil, config={}, app=App.instance, argv=[])
        new(name, config, app).enq(*argv)
      end
      
      def parse_argv(argv) # => name, config, argv
        config = {}
        opts = OptionParser.new

        # Add configurations
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end
        
        configurations.each do |receiver, key, configuration|
          opts.on(*configuration.to_option_parser_argv) do |value|
            config[key] = value
          end
        end
      
        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"
        
        opts.on_tail("-h", "--help", "Print this help") do
          yield(opts)
        end if block_given?

        name = nil
        opts.on_tail('--name NAME', /^[^-].*/, 'Specify a name') do |value|
          name = value
        end

        opts.on_tail('--use FILE', /^[^-].*/, 'Loads inputs from file') do |v|
          hash = YAML.load_file(value)
          hash.values.each do |args| 
            ARGV.concat(args)
          end
        end

        opts.parse!(argv)
        
        [name, config, argv]
      end
      
    end
  end
end