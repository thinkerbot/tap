module Tap
  module Support
    autoload(:TDoc, 'tap/support/tdoc')
    autoload(:CommandLine, 'tap/support/command_line')
    
    # FrameworkMethods encapsulates class methods related to Framework.
    module FrameworkMethods
      
      # ConfigurableMethods initializes base.configurations on extend.
      def self.extended(base)
        base.instance_variable_set(:@source_file, nil)
        base.instance_variable_set(:@help_template, DEFAULT_HELP_TEMPLATE)
      end
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        child.instance_variable_set(:@source_file, nil)
        child.instance_variable_set(:@help_template, help_template)
      end
      
      # Identifies source files for TDoc documentation.
      attr_accessor :source_file # :nodoc:
      
      DEFAULT_HELP_TEMPLATE = %Q{<%= task_class %><%= tdoc.summary.to_s.strip.empty? ? '' : ' -- ' %><%= tdoc.summary %>

<% tdoc.desc(78).each do |line| %>
  <%= line %>
<% end %>

<%= opts.to_s %>}

      # Returns to the path for the class help template.  By default
      # the DEFAULT_HELP_TEMPLATE.
      attr_accessor :help_template
      
      # Returns the default name for the class: to_s.underscore
      def default_name
        @default_name ||= to_s.underscore
      end

      # Returns the TDoc documentation for self. 
      def tdoc
        @tdoc ||= TDoc[self]
      end
      
      def parse_argv(argv, exit_on_help=false) # => name, config, argv
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
          opts.banner = "usage: tap run -- #{tdoc.usage}"
          configurations.each do |receiver, key, configuration|
            configuration.desc = receiver.tdoc.config[key]
          end
          
          print Templater.new(help_template, 
            :task_class => self, 
            :tdoc => tdoc, 
            :opts => opts
          ).build
          
          exit if exit_on_help
        end

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