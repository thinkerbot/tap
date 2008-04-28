module Tap
  module Support
    autoload(:TDoc, 'tap/support/tdoc')
    autoload(:CommandLine, 'tap/support/command_line')
    
    # Under Construction
    module CommandLineMethods
      
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
        task = new(ARGV.shift, config, app)
        iterate ? ARGV.each {|input| task.enq(input) } : task.enq(*ARGV)
      end
    end
    
  end
end