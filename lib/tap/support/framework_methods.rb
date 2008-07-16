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
        base.instance_variable_set(:@help_template, DEFAULT_HELP_TEMPLATE)
      end
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        caller.first =~ /^(([A-z]:)?[^:]+):(\d+)/
        child.instance_variable_set(:@tdoc, TDoc.instance.document_for($1))
        child.instance_variable_set(:@help_template, help_template)
      end
      
      # Identifies source files for TDoc documentation.
      attr_reader :tdoc
      
      DEFAULT_HELP_TEMPLATE = %Q{<%= task_class %><%= manifest.subject.to_s.strip.empty? ? '' : ' -- ' %><%= manifest.subject %>

<% unless manifest.empty? %>

<% manifest.to_s(' ', nil, 78, 2).each do |line| %>
  <%= line %>
<% end %>
<% end %>

<%= opts.to_s %>}

      # Returns to the path for the class help template.  By default
      # the DEFAULT_HELP_TEMPLATE.
      attr_accessor :help_template
      
      # Returns the default name for the class: to_s.underscore
      def default_name
        @default_name ||= to_s.underscore
      end

      def enq(name=nil, config={}, app=App.instance, argv=[])
        new(name, config, app).enq(*argv)
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
          tdoc.resolve(nil, /^\s*def\s+process(\((.*?)\))?/) do |comment, match|
            comment.subject = match[2].to_s.split(',').collect do |arg|
              arg = arg.strip.upcase
              case arg
              when /^&/ then nil
              when /^\*/ then arg[1..-1] + "..."
              else arg
              end
            end.join(', ')

            tdoc['']['args'] ||= comment
          end
          
          configurations.resolve_documentation

          manifest = tdoc[self.to_s]['manifest'] || Comment.new
          args = tdoc[self.to_s]['args'] || Comment.new

          opts.banner = "usage: tap run -- #{self.to_s.underscore} #{args.subject}"
          
          print Templater.new(help_template, 
            :task_class => self, 
            :manifest => manifest, 
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