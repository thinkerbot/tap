require 'optparse'

module Tap
  module Support
    
    # Under Construction
    module CommandLine
      module_function

      # Parses the input string as YAML, if the string matches the YAML document 
      # specifier (ie it begins with "---\s*\n").  Otherwise returns the string.
      #
      #   str = {'key' => 'value'}.to_yaml    # => "--- \nkey: value\n"
      #   Tap::Script.parse_yaml(str)            # => {'key' => 'value'}
      #   Tap::Script.parse_yaml("str")          # => "str"
      def parse_yaml(str)
        str =~ /\A---\s*\n/ ? YAML.load(str) : str
      end
      
      SPLIT_ARGV_REGEXP = /\A-{2}(\+*)\z/
      
      def split(argv)
        current = []
        current_split = []
        splits = [current_split]

        argv.each do |arg|
          if arg =~ SPLIT_ARGV_REGEXP
            current_split << current  unless current.empty?
            current = []
            current_split = (splits[$1.length] ||= [])
          else
            current << arg
          end
        end

        current_split << current unless current.empty?
        splits.delete_if {|split| split.nil? || split.empty? }
        splits
      end

      def shift(argv)
        index = nil
        argv.each_with_index do |arg, i|
          if arg !~ /\A-/
            index = i 
            break
          end
        end
        index == nil ? nil : argv.delete_at(index)
      end

      def usage(path, cols=80)
        parse_usage(File.read(path), cols)
      end
        
      def parse_usage(str, cols=80)
        scanner = StringScanner.new(str)
        scanner.scan(/^#!.*?$/)
        Comment.parse(scanner, false).wrap(cols, 2).strip
      end
      
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
      
      def instantiate(framework_class, argv, app=Tap::App.instance) # => obj, argv
        opts = OptionParser.new
        configurations = framework_class.configurations
        
        # Add configurations
        config = {}
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end
        
        configurations.each do |receiver, key, configuration|
          opts.on(*configv(configuration)) do |value|
            config[key] = value
          end
        end
      
        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"
        
        opts.on_tail("-h", "--help", "Print this help") do
          lazydoc = framework_class.lazydoc
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
       
          Lazydoc.resolve(configurations.code_comments)

          manifest = lazydoc[to_s]['manifest'] || Tap::Support::Comment.new
          args = lazydoc[to_s]['args'] || Tap::Support::Comment.new

          opts.banner = "usage: tap run -- #{framework_class.to_s.underscore} #{args.subject}" if opts
        
          puts Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, 
            :task_class => framework_class, 
            :manifest => manifest, 
            :opts => opts
          ).build
          
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
        obj = framework_class.new({}, name, app)
        
        path_configs = app.load_config(app.config_filepath(name))
        if path_configs.kind_of?(Array)
          path_configs.each_with_index do |path_config, i|
            obj.initialize_batch_obj(path_config, "#{name}_#{i}") unless i == 0
          end
          path_configs = path_configs[0]
        end
        
        [obj.reconfigure(path_configs).reconfigure(config), argv]
      end
      
      def configv(config)
        desc = config.desc
        desc.extend(OptParseComment) if desc.kind_of?(Comment)
          
        [config.short, argtype(config), desc].compact
      end
      
      def argtype(config)
        case config.arg_type
        when :optional 
          "#{config.long} [#{config.arg_name}]"
        when :switch 
          config.long(true)
        when :flag
          config.long
        when :list
          "#{config.long} a,b,c"
        when :mandatory, nil
          "#{config.long} #{config.arg_name}"
        else
          raise "unknown arg_type: #{config.arg_type}"
        end
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