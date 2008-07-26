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
            base.instance_variable_set(:@source_file, File.expand_path($1))
            break
          end
        end
        base.instance_variable_set(:@default_name, base.to_s.underscore)
      end
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        caller.first =~ /^(([A-z]:)?[^:]+):(\d+)/
        child.instance_variable_set(:@source_file, File.expand_path($1))
        child.instance_variable_set(:@default_name, child.to_s.underscore)
      end
      
      # The source_file for self.  By default the first file
      # to define the class inheriting FrameworkMethods.
      attr_accessor :source_file
      
      # Returns the tdoc for source_file
      def tdoc
        Lazydoc[source_file]
      end
      
      # Returns the default name for the class: to_s.underscore
      attr_accessor :default_name
      
      DEFAULT_HELP_TEMPLATE = %Q{<%= task_class %><%= manifest.subject.to_s.strip.empty? ? '' : ' -- ' %><%= manifest.subject %>

<% unless manifest.empty? %>
<%= '-' * 80 %>

<% manifest.wrap(77, 2, nil).each do |line| %>
  <%= line %>
<% end %>
<%= '-' * 80 %>
<% end %>

<%= opts.to_s %>
}

      def help(opts)
        tdoc.resolve(nil, /^\s*def\s+process(\((.*?)\))?/) do |comment, match|
          comment.subject = match[2].to_s.split(',').collect do |arg|
            arg = arg.strip.upcase
            case arg
            when /^&/ then nil
            when /^\*/ then arg[1..-1] + "..."
            else arg
            end
          end.join(', ')
       
          tdoc.default_attributes['args'] ||= comment
        end
       
        Lazydoc.resolve(configurations.code_comments)

        manifest = tdoc[to_s]['manifest'] || Tap::Support::Comment.new
        args = tdoc[to_s]['args'] || Tap::Support::Comment.new

        opts.banner = "usage: tap run -- #{to_s.underscore} #{args.subject}"
        
        Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, 
          :task_class => self, 
          :manifest => manifest, 
          :opts => opts
        ).build
      end
      
      def parse_argv(argv, app=Tap::App.instance) # => config, name, argv
        opts = OptionParser.new

        # Add configurations
        config = {}
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end
        
        configurations.each do |receiver, key, configuration|
          desc = configuration.desc
          desc.extend(OptParseComment) if desc.kind_of?(Comment)
          
          configv = [configuration.short, configuration.arg_type_for_option_parser, desc]
          opts.on(*configv.compact) do |value|
            config[key] = value
          end
        end
      
        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"
        
        opts.on_tail("-h", "--help", "Print this help") do
          print help(opts)
          exit
        end
        
        # Add option for name
        name = nil
        opts.on_tail('--name NAME', /^[^-].*/, 'Specify a name') do |value|
          name = value
        end
        
        # Add option to add args
        opts.on_tail('--use FILE', /^[^-].*/, 'Loads inputs from file') do |v|
          hash = YAML.load_file(value)
          hash.values.each do |args| 
            ARGV.concat(args)
          end
        end

        opts.parse!(argv)
        
        [config, name, argv]
      end
      
      def argv_new(argv, app=Tap::App.instance) # => obj, argv
        config, name, argv = parse_argv(argv)
        obj = new({}, name, app)
        
        path_configs = app.load_config(app.config_filepath(name))
        if path_configs.kind_of?(Array)
          path_configs.each_with_index do |path_config, i|
            obj.initialize_batch_obj(path_config, "#{name}_#{i}") unless i == 0
          end
          path_configs = path_configs[0]
        end
        
        [obj.reconfigure(path_configs).reconfigure(config), argv]
      end
      
      module OptParseComment
        def empty?
          to_str.empty?
        end

        def to_str
          subject.to_s =~ /#(.*)$/ ? $1.strip : ""
        end
      end
    end
  end
end