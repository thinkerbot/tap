require 'tap/task'
require 'stringio'

module Tap
  module Tasks
    # :startdoc::task the default load task
    #
    # Loads data from $stdin.  String data may be passed directly.  Load
    # is typically used as a gateway to other tasks.
    #
    #   % tap run -- load string --: dump
    #   string
    #
    # Load facilitates normal redirection:
    #
    #   % echo goodnight moon | tap run -- load --: dump
    #   goodnight moon
    #
    #   % tap run -- load --: dump < somefile.txt
    #   contents of somefile
    #
    # :startdoc::task-
    #
    # Load serves as a baseclass for more complicated loads.  A YAML load
    # (see {tap-tasks}[http://tap.rubyforge.org/tap-tasks]) looks like this:
    #
    #   class Yaml < Tap::Tasks::Load
    #     def load(io)
    #       YAML.load(io)
    #     end
    #   end
    #
    # Load is constructed to reque itself in cases where objects are to
    # be read sequentially from the same io.  Normally load will reque until
    # the end-of-file is reached, but this behavior can be modified by
    # overriding the complete? method.  An example is a prompt task:
    #
    #   class Prompt < Tap::Tasks::Load
    #     config :exit_seq, "\n"
    #
    #     def load(io)
    #       if io.eof?
    #         nil
    #       else
    #         io.readline
    #       end
    #     end
    #
    #     def complete?(io, line)
    #       line == nil || line == exit_seq
    #     end
    #   end
    #
    # Note that Load closes io when complete? is true.  If this behavior
    # is undesirable, or if io requires a fancy cleanup, override the
    # close method.
    class Load < Tap::Task
      
      config :file, false, &c.flag         # Opens the input as a file
      
      # Loads data from io.  Process will open the input io object, load
      # a result, then check to see if the loading is complete (using the
      # complete? method).  If loading is complete, process will close io.
      # Otherwise process will (re)enque io to self.
      def process(io=$stdin)
        io = open(io)
        result = load(io)
        
        if complete?(io, result)
          close(io)
        else
          enq(io)
        end
        
        result
      end
      
      # Opens the io; specifically this means:
      #
      # * Opening a File for String inputs (file true)
      # * Creating a StringIO for String inputs (file false)
      # * Opening an IO for integer file descriptors
      # * Returning all other objects
      #
      def open(io)
        case io
        when String
          if file
            File.open(io)
          else
            StringIO.new(io)
          end
        when Integer
          IO.open(io)
        else 
          io
        end
      end
      
      # Loads data from io using io.read.  Load is intended as a hook
      # for subclasses.
      def load(io)
        io.read
      end
      
      # Closes io.
      def close(io)
        io.close
      end
      
      # Returns io.eof?  Override in subclasses for the desired behavior
      # (see process).
      def complete?(io, last)
        io.eof?
      end
    end
  end
end
