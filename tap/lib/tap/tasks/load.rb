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
    # could look like this:
    #
    #   class Yaml < Tap::Tasks::Load
    #     def load(io)
    #       YAML.load(io)
    #     end
    #   end
    #
    # Load subclasses may be constructed to reque itself in cases where objects
    # are sequentially loaded from the same io.  Load will reque until the
    # complete? method returns true.  An example is a prompt task:
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
    # If the use_close configuration is specified, load will close io upon
    # completion.  Files opened by load are always closed upon completion.
    #
    class Load < Tap::Task
      
      config :file, false, &c.flag                         # Opens the input as a file
      config :use_close, false, :long => :close, &c.flag   # Close the input when complete
      
      # Loads data from io.  Process will open the input io object, load
      # a result, then check to see if the loading is complete (using the
      # complete? method).  Unless loading is complete, process will enque
      # io to self.  Process will close io when loading is complete, provided
      # use_close or file is specified.
      def process(io=$stdin)
        io = open(io)
        result = load(io)
        
        if complete?(io, result)
          if use_close || file
            close(io)
          end
        else
          enq(io)
        end
        
        result
      end
      
      # Opens the io; specifically this means:
      #
      # * Opening a File (file true)
      # * Creating a StringIO for String inputs
      # * Opening an IO for integer file descriptors
      # * Returning all other objects
      #
      def open(io)
        return(io.kind_of?(File) ? io : File.open(io)) if file
        
        case io
        when String
          StringIO.new(io)
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
      
      # Returns true by default.  Override in subclasses to allow recurrent 
      # loading (see process).
      def complete?(io, last)
        true
      end
    end
  end
end
