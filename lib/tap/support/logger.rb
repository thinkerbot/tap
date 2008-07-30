require 'logger'

module Tap
  module Support
    
    # == UNDER CONSTRUCTION
    # Logger provides methods to extend Logger objects.  
    #
    # The output format is designed to look nice in a command prompt, but provide useful information
    # if directed at a log file.  The Logger output format is like:
    #
    #   I[datetime]    action  message
    #--
    # The first letter ('I' - INFO) indicates the severity of the message, next comes the datetime of the
    # log, the type of log message, then the message itself.  Specify the log type and message like:
    #
    #   logger.type "message"
    #
    # Typed logging occurs through +method_missing+.  Any type is possible so long as the logger doesn't
    # already have a method of the input type.
    #++
    #
    #--
    # TODO
    # multiplex logger so that logging can be directed to two locations; a log file and the console for
    # example, or log files in multiple locations.
    #++
    module Logger
      DEFAULT_FORMAT = "  %s[%s] %18s %s\n"
      DEFAULT_TIMESTAMP = "%H:%M:%S"
      
      def self.extended(base)
        # On OS X (and maybe other systems), $stdout is not sync-ed.  
        # Set sync to true so that writes are immediately flushed
        # to the console.
        if base.logdev.respond_to?(:dev) && base.logdev.dev == $stdout
          base.logdev.dev.sync = true
        end
        
        if base.datetime_format == nil
          base.datetime_format = DEFAULT_TIMESTAMP
        end
        
        unless base.instance_variable_defined?(:@format)
          base.instance_variable_set(:@format, DEFAULT_FORMAT)
        end
      end
      
      attr_accessor :format
      
      # Provides direct access to the log device
      def logdev
        @logdev
      end
      
      # Same as add, but uses the format provided by the block.
      # BUG: not thread safe
      def format_add(level, msg, action=nil, &block)
        current_format = self.format
        self.format = yield(current_format)
        add(level, msg, action.to_s)
        self.format = current_format
      end
      
      # Overrides the default format message to produce output like:
      #
      #   I[H:M:S]           type message
      #
      # If no progname is specified, '--' is used.
      def format_message(severity, timestamp, progname, msg, format=self.format)
        if timestamp.respond_to?(:strftime) && self.datetime_format
          timestamp = timestamp.strftime(self.datetime_format) 
        end
        
        format % [severity[0..0], timestamp, progname || '--' , msg]
      end
      
      # Convenience method for creating section breaks in the output, formatted like:
      #
      #                     -----  message  -----
      def section_break(message)
        @logdev.write("                  -----  #{message}  -----\n")
      end

      private
      
      INFO = Object::Logger::INFO
      
      # Specifies that any unknown method calls will be treated as logging calls where the method
      # is the log type, and the first argument is the message.  Types are underscored before logging.
      def method_missing(method, *args, &block)
        add(INFO, args.first, method.to_s.underscore, &block)
      end
    end
  end
end