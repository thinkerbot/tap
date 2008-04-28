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

      def split_argv(argv)
        current = []
        current_split = []
        splits = [current_split]

        argv.each do |arg|
          if arg =~ /\A-{2}(\+*)\z/
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

      def next_arg(argv)
        index = nil
        argv.each_with_index do |arg, i|
          if arg !~ /\A-/
            index = i 
            break
          end
        end
        index == nil ? nil : argv.delete_at(index)
      end

      # Handles options using GetoptLong, and passes each option and
      # value in ARGV to the block. 
      #
      #--
      # expect [long, <short>, type, desc]
      #++
      def handle_options(*options)
        options = options.collect do |opt|
          opt = opt[0..-2]
          opt.compact
        end

        opts = GetoptLong.new(*options)
        opts.quiet = true
        opts.each do |opt, value| 
          yield(opt, value)
        end
      end
      
      def command_help(program_file, opts)
        lines = []
        lines << usage(program_file, "Usage", "Description", :keep_headers => false)
        unless opts.empty?
          lines.concat ["Options:", usage_options(opts)]
        end
        lines.join("\n")
      end

      def usage(program_file, *sections)
        options = sections.last.kind_of?(Hash) ? sections.pop : {}
        options = {:keep_headers => true}.merge(options)
        comment = Tap::Support::TDoc.usage(program_file, sections, options[:keep_headers])
        comment.rstrip + "\n"
      end

      def usage_options(opts)
        opt_lines = []
        opts.each do |long, short, mode, desc|

          if desc.kind_of?(Class) && desc.include?(Tap::Support::Configurable)
            key = desc.configurations.opt_map(long)
            default = PP.singleline_pp(desc.configurations.default[key], "")
            config_attr = desc.tdoc.find_configuration_named(key.to_s)
            desc = config_attr.desc
          end

          short = short == nil ? "    " : "(#{short})"
          opt_lines << "  %-25s %s      %s" % [long, short, desc]
        end
        opt_lines.join("\n")
      end
      
    end
  end
end