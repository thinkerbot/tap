require 'tap/task'

module Tap

  # :startdoc::manifest the default dump task
  #
  # A dump task to print results to $stdout or a file target.
  #
  #   % tap run -- [task] --: dump --target FILEPATH
  #
  # Results that come to dump are appended to the file.  Dump only accepts
  # one object at a time, so joins that produce an array need to iterate
  # outputs to dump:
  #
  #   % tap run -- load hello -- load world "--2(0,1)i" dump 
  #
  # Note that dump faciliates normal redirection:
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
    lazy_attr :args, :setup
    lazy_register :setup, Lazydoc::Arguments
    
    config :target, $stdout, &c.io(:<<, :puts, :print)   # The dump target file
    config :overwrite, false, &c.flag                    # Overwrite the existing target
    config :audit, false, &c.flag                        # Include the audit trails
    config :date, false, &c.flag                         # Include a date
    config :date_format, '%Y-%m-%d %H:%M:%S'             # The date format
    
    def call(_input)
      _audit = Support::Audit.new(self, _input.value, app.audit ? _input : nil)
      process(_audit)
    end
    
    # The default process prints dump headers as specified in the config,
    # then append the audit value to io.
    def process(_audit)
      unless _audit.kind_of?(App::Audit)
        # note the nil-source audit is added for consistency with _execute
        previous = App::Audit.new(nil, _audit)
        _audit = App::Audit.new(self, _audit, previous)
      end
      
      open_io(target, overwrite ? 'w' : 'a') do |io|
        if date
          io.puts "# date: #{Time.now.strftime(date_format)}"
        end

        if audit
          io.puts "# audit:"
          io.puts "# #{_audit.dump.gsub("\n", "\n# ")}"
        end
        
        dump(_audit.value, io)
      end
      target
    end
    
    # Dumps the object to io, by default dump puts (not prints) obj.to_s.
    def dump(obj, io)
      io.puts obj.to_s
    end
  end
end