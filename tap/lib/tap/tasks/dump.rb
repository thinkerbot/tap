module Tap
  module Tasks
    # :startdoc::manifest the default dump task
    #
    # A dump task to print results as YAML.  Unlike most tasks, dump arguments
    # do not enque to the task; instead the arguments are used to setup a
    # dump and the dump uses whatever results come to them in a workflow.
    #
    # Multiple dumps to the same file append rather than overwrite.  If no file
    # is specified, the dump goes to $stdout.
    #
    #   % tap run -- [task] --: dump FILEPATH
    #
    # Results may be printed directly, without conversion to YAML by using the
    # --no-yaml option.
    #
    # :startdoc::manifest-
    #
    # Dumps are organized so that arguments passed on the command line are
    # directed at setup rather than process.  Moreover, process will always
    # receive the audits passed to _execute, rather than the audit values.
    # This allows a user to provide setup arguments (such as a dump path)
    # on the command line, and provides dump the opportunity to inspect
    # audit trails.
    #
    class Dump < Tap::FileTask
      class << self
        
        # Same as an ordinary parse!, except the arguments normally reserved for
        # executing the task are used to call setup.  The return will always be
        # an instance and an empty array.
        def parse!(argv=ARGV, app=Tap::App.instance)
          instance, args = super
          instance.setup(*args)
          [instance, []]
        end
      end
      
      lazy_attr :args, :setup
      lazy_register :setup, Lazydoc::Arguments
      
      config :date_format, '%Y-%m-%d %H:%M:%S'   # the date format
      config :audit, true, &c.switch             # include the audit trails
      config :date, true, &c.switch              # include a date
      config :yaml, true, &c.switch              # dump as yaml (vs string)
      
      # The dump target, by default $stdout.  Target may be a filepath,
      # in which case dumps append the file.
      attr_accessor :target
      
      def initialize(config={}, name=nil, app=App.instance, target=$stdout)
        super(config, name, app)
        @target = target
      end
      
      # Setup self with the input target.  Setup is typically called from
      # parse! and receives arguments passed from the command line.
      def setup(path=target)
        @target = path
      end
      
      # Overrides the standard _execute to send process the audits and not
      # the audit values.  This allows process to inspect audit trails.
      def _execute(*inputs)
        resolve_dependencies
        
        previous = []
        inputs.collect! do |input| 
          if input.kind_of?(Support::Audit) 
            previous << input
            input.value
          else
            previous << Support::Audit.new(nil, input)
            input
          end
        end
        
        # this is the overridden part
        audit = Support::Audit.new(self, inputs, previous)
        send(method_name, audit)
        
        if complete_block = on_complete_block || app.on_complete_block
          complete_block.call(audit)
        else 
          app.aggregator.store(audit)
        end
        
        audit
      end
      
      # Prints the _audit to the target.  The return value of process is
      # not recorded in the audit trail.
      def process(_audit)
        open_io do |io|
          if date
            io.puts "# date: #{Time.now.strftime(date_format)}"
          end
          
          if audit
            io.puts "# audit:"
            io.puts "# #{_audit.dump.gsub("\n", "\n# ")}"
          end
          
          if yaml
            YAML::dump(_audit.value, io)
          else
            io << _audit.value.to_s
          end
        end
      end
      
      protected
      
      # helper to open and yield the io specified by target.  open_io
      # ensures file targets are closed when the block returns.
      def open_io # :nodoc:
        case target
        when IO, StringIO then yield(target)
        when String then File.open(target, 'a') {|io| yield(io) }  
        else raise "cannot open target: #{target.inspect}"
        end
      end
    end
  end
end