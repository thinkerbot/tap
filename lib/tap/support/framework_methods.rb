module Tap
  module Support
    autoload(:TDoc, 'tap/support/tdoc')
    autoload(:CommandLine, 'tap/support/command_line')
    
    # FrameworkMethods encapsulates class methods related to Framework.
    module FrameworkMethods
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        child.instance_variable_set(:@source_files, source_files.dup)
      end

      # EXPERIMENTAL
      attr_reader :source_files # :nodoc:

      # EXPERIMENTAL
      # Identifies source files for TDoc documentation.
      def source_file(arg) # :nodoc:
        source_files << arg
      end
      
      # Returns the default name for the class: to_s.underscore
      def default_name
        @default_name ||= to_s.underscore
      end

      # Returns the TDoc documentation for self. 
      def tdoc
        @tdoc ||= Tap::Support::TDoc[self]
      end

      # EXPERIMENTAL
      def help(opts=configurations.to_opts) 
        return "could not find help for '#{self}'" if tdoc == nil

        sections = tdoc.comment_sections(/Description|Usage/i, true)
        %Q{#{self}
#{sections["Description"]}
Usage:
#{sections["Usage"]}
Options:
#{Tap::Support::CommandLine.usage_options(opts)}

}
      end

      # EXPERIMENTAL
      def argv_enq(app=App.instance, &block) 
        if block_given?
          @argv_enq_block = block
          return
        end
        return @argv_enq_block.call(app) if @argv_enq_block ||= nil

        config = {}
        opts = configurations.to_opts
        opts << ['--help', nil, GetoptLong::NO_ARGUMENT, "Print this help."]
        opts << ['--debug', nil, GetoptLong::NO_ARGUMENT, "Trace execution and debug"]
        opts << ['--use', nil, GetoptLong::REQUIRED_ARGUMENT, "Loads inputs from file."]
        opts << ['--iterate', nil, GetoptLong::NO_ARGUMENT, "Iterates over inputs."]

        iterate = false
        Tap::Support::CommandLine.handle_options(*opts) do |opt, value|
          case opt
          when '--help'
            puts help(opts)
            exit

          when '--debug'
            app.options.debug = true

          when '--use'
            hash = YAML.load_file(value)
            hash.values.each do |args| 
              ARGV.concat(args)
            end

          when '--iterate'
            iterate = true

          else
            key = configurations.opt_map(opt)
            config[key] = YAML.load(value)
          end
        end

        # instantiate and configure task
        ARGV.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
        task = new(ARGV.shift, config, app)
        iterate ? ARGV.each {|input| task.enq(input) } : task.enq(*ARGV)
      end
      
    end
  end
end