require 'tap/task'
require 'stringio'

module Tap
  module Tasks
    # :startdoc::task load data
    #
    # Loads data from $stdin.  String data may be passed directly.  Load
    # is typically used as a gateway to other tasks.
    #
    #   % tap load string -: dump
    #   string
    #
    # Load facilitates normal redirection:
    #
    #   % echo goodnight moon | tap load -: dump
    #   goodnight moon
    #
    #   % tap load -: dump < somefile.txt
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
    # If the use_close configuration is specified, load will close io upon
    # completion.  Files opened by load are always closed upon completion.
    #
    class Load < Tap::Task
      
      config :file, false, &c.flag                         # Opens the input as a file
      config :use_close, false, :long => :close, &c.flag   # Close the input when complete
      
      # Loads data from io.  Process will open the input io object, load
      # a result.  Process will close io when loading is complete, provided
      # use_close or file is specified.
      def process(io=$stdin)
        io = open(io)
        result = load(io)
        
        if use_close || file
          close(io)
        end
        
        result
      end
      
      # Opens the io; specifically this means:
      #
      # * Creating a StringIO for String inputs
      # * Opening an IO for integer file descriptors
      # * Returning all other objects
      #
      def open(io)
        return open_file(io) if file
        
        case io
        when String
          StringIO.new(io)
        when Integer
          IO.open(io)
        else 
          io
        end
      end
      
      # Opens io as a File.
      def open_file(io)
        io.kind_of?(File) ? io : File.open(io)
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
    end
  end
end
