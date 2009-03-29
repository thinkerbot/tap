module Tap

  # :startdoc::manifest the default dump task
  #
  # A dump task to output results.  Unlike most tasks, dump does not enque
  # arguments from the command line; instead command line arguments are only
  # used to setup the dump.  Specifically dump accepts a filepath.
  #
  #   % tap run -- [task] --: dump FILEPATH
  #
  # Results that come to dump are appended to the file.  Dump only accepts
  # one object at a time, so joins that produce an array need to iterate
  # outputs to dump:
  #
  #   % tap run -- load hello -- load world "--2(0,1)i" dump 
  #
  # Note that dump uses $stdout by default so you can pipe or redirect dumps
  # as normal.
  #
  #   % tap run -- load hello --: dump | cat
  #   hello
  #
  #   % tap run -- load hello --: dump 1> results.txt
  #   % cat results.txt
  #   hello
  #
  # :startdoc::manifest-
  #
  # Dump serves as a baseclass for more complicated dump tasks.  A YAML dump
  # task (see {tap-tasks}[http://tap.rubyforge.org/tap-tasks]) looks like this:
  #
  #   class Yaml < Tap::Dump
  #     def dump(obj, io)
  #       YAML.dump(obj, io)
  #     end
  #   end
  #
  # === Implementation Notes
  #
  # Dump passes on the command line arguments to setup rather than process.
  # Moreover, process will always receive the audits passed to _execute, rather
  # than the audit values. This allows a user to provide setup arguments (such
  # as a dump path) on the command line, and provides dump the opportunity to
  # inspect audit trails within process.
  #
  class Dump < Tap::Task
    class << self
      
      # Same as an ordinary instantiate, except the arguments normally reserved
      # for executing the task are used to call setup.  The return will always
      # be an instance and an empty array.
      def instantiate(argh={}, app=Tap::App.instance)
        instance, args = super
        instance.setup(*args)
        [instance, []]
      end
    end
    
    lazy_attr :args, :setup
    lazy_register :setup, Lazydoc::Arguments
    
    config :date_format, '%Y-%m-%d %H:%M:%S'   # The date format
    config :audit, false, &c.switch            # Include the audit trails
    config :date, false, &c.switch             # Include a date
    
    # The dump target, by default $stdout.  Target may be a filepath,
    # in which case dumps append the file.
    attr_accessor :target
    
    def initialize(config={}, name=nil, app=App.instance)
      super(config, name, app)
      @target = $stdout
    end
    
    # Setup self with the input target.  Setup receives arguments passed from
    # the command line, via parse!
    def setup(output=$stdout)
      @target = output
      self
    end
    
    # Overrides the standard _execute to send process the audits and not
    # the audit values.  This allows process to inspect audit trails.
    def _execute(input)
      resolve_dependencies
      
      previous = input.kind_of?(Support::Audit) ? input : Support::Audit.new(nil, input)
      input = previous.value
      
      # this is the overridden part
      audit = Support::Audit.new(self, input, app.audit ? previous : nil)
      send(method_name, audit)
      
      if complete_block = on_complete_block || app.on_complete_block
        complete_block.call(audit)
      else 
        app.aggregator.store(audit)
      end
      
      audit
    end
    
    # The default process prints dump headers as specified in the config,
    # then append the audit value to io.
    def process(_audit)
      open_io(target, 'a') do |io|
        if date
          io.puts "# date: #{Time.now.strftime(date_format)}"
        end

        if audit
          io.puts "# audit:"
          io.puts "# #{_audit.dump.gsub("\n", "\n# ")}"
        end
        
        dump(_audit.value, io)
      end
    end
    
    # Dumps the object to io, by default dump puts (not prints) obj.to_s.
    def dump(obj, io)
      io.puts obj.to_s
    end
  end
end