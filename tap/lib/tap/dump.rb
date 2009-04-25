require 'tap/task'

module Tap

  # :startdoc::task the default dump task
  #
  # A dump task to print results to $stdout or a file output.
  #
  #   % tap run -- dump content --output FILEPATH
  #
  # Results that come to dump are appended to the file.  Dump only accepts
  # one object at a time, so joins that produce an array (like sync) need
  # to iterate outputs to dump:
  #
  #   % tap run -- load hello -- load world -- dump --[0,1][2]i.sync
  #   hello
  #   world
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
  # :startdoc::task-
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
  class Dump < Tap::Task
    config :output, $stdout, &c.io(:<<, :puts, :print)   # The dump target file
    config :overwrite, false, &c.flag                    # Overwrite the existing target
    
    # The default process prints dump headers as specified in the config,
    # then append the audit value to io.
    def process(input)
      open_io(output, overwrite ? 'w' : 'a') do |io|
        dump(input, io)
      end
      output
    end
    
    # Dumps the object to io, by default dump puts (not prints) obj.to_s.
    def dump(input, io)
      io.puts input.to_s
    end
  end
end