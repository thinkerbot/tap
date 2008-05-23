module Tap
  module Support
    autoload(:TDoc, 'tap/support/tdoc')
    autoload(:CommandLine, 'tap/support/command_line')
    
    # FrameworkMethods encapsulates class methods related to Framework.
    module FrameworkMethods
      
      # ConfigurableMethods initializes base.configurations on extend.
      def self.extended(base)
        base.instance_variable_set(:@source_files, [])
        base.instance_variable_set(:@options, [])
      end
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        child.instance_variable_set(:@source_files, source_files.dup)
        child.instance_variable_set(:@options, options.dup)
        # options.collect {|opt| opt.dup}
        # maybe avoid this by freezing the standard options?
      end

      # EXPERIMENTAL
      attr_reader :source_files # :nodoc:
      
      attr_reader :options
      
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
      def help(opts=Tap::Support::CommandLine.to_opts(configurations)) 
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
      
      def parse_argv(argv)
        # => name, config, remaining argv
      end
      
      def opt
      end
      
      # EXPERIMENTAL
      def argv_enq(app=App.instance, &block) 
        if block_given?
          @argv_enq_block = block
          return
        end
        return @argv_enq_block.call(app) if @argv_enq_block ||= nil

        config = {}
        iterate = false
        OptionParser.new do |opts|

          #
          # Add configurations
          #

          unless configurations.empty?
            opts.separator ""
            opts.separator "Configurations:"
          end
          
          configurations.each_pair do |key, configuration|
            opts.on(*configuration.to_option_parser_argv) do |value|
              config[key] = YAML.load(value)
            end
          end
        
          #
          # Add options on_tail, giving priority to configurations
          #
        
          opts.separator ""
          opts.separator "Options:"
          
          opts.on_tail("-h", "--help", "Print this help") do
            puts Tap::Support::CommandLine.usage(__FILE__, "Usage", "Description", :keep_headers => false)
            puts
            puts opts

            exit
          end

          opts.on_tail('-d', '--debug', 'Trace execution and debug') do |v|
            app.options.debug = v
          end

          opts.on_tail('--use FILE', 'Loads inputs from file') do |v|
            hash = YAML.load_file(value)
            hash.values.each do |args| 
              ARGV.concat(args)
            end
          end

          opts.on_tail('--iterate', 'Iteratively enques inputs') do |v|
            iterate = true
          end
        end.parse!(ARGV)

        iterate = false


        # instantiate and configure task
        ARGV.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
        task = new(ARGV.shift, config, app)
        iterate ? ARGV.each {|input| task.enq(input) } : task.enq(*ARGV)
      end
      
    end
  end
end