require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task the default dump task
    #
    # Dumps data to $stdout or a file output.
    #
    #   % tap run -- dump content --output FILEPATH
    #
    # Dump faciliates normal redirection:
    #
    #   % tap run -- load hello --: dump | more
    #   hello
    #
    #   % tap run -- load hello --: dump 1> results.txt
    #   % more results.txt
    #   hello
    #
    # Note that dumps are appended to the file.  Dump only accepts one object
    # at a time, so joins that produce an array (like sync) need to iterate
    # outputs to dump:
    #
    #   % tap run -- load hello -- load world -- dump --[0,1][2]i.sync
    #   hello
    #   world
    #
    # :startdoc::task-
    #
    # Dump serves as a baseclass for more complicated dumps.  A YAML dump
    # (see {tap-tasks}[http://tap.rubyforge.org/tap-tasks]) looks like this:
    #
    #   class Yaml < Tap::Tasks::Dump
    #     def dump(obj, io)
    #       YAML.dump(obj, io)
    #     end
    #   end
    #
    class Dump < Tap::Task
      config :output, $stdout, &c.io(:<<, :puts, :print)   # The dump target file
      config :overwrite, false, &c.flag                    # Overwrite the existing target
    
      # The default process prints dump headers as specified in the config,
      # then append the audit value to io.
      def process(input)
        open_io(output, overwrite ? 'w' : 'a') do |io|
          dump(input, io)
        end
        input
      end
    
      # Dumps the object to io, by default dump puts (not prints) obj.to_s.
      def dump(input, io)
        io.puts input.to_s
      end
      
      def to_spec
        spec = super
        spec['config'].delete('output') if output == $stdout
        spec
      end
    end
  end
end