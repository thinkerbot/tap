module Tap
  module Support

    # Represents a task node in a Schema.  Nodes consist of an argv, source,
    # and join. The argv is normally used to lookup and instantiate a task 
    # instance via <TaskClass>.instantiate.  The source and join are used to
    # determine when and with which inputs to execute the instance.
    #
    class Node
      Join = Struct.new :type, :options
      
      attr_accessor :argv
      attr_accessor :input
      attr_accessor :output

      def initialize(argv=[], input=nil, output=nil)
        @argv = argv
        @input = input
        @output = output
      end
      
      # Resets the source and join to nil.
      def reset
        self.input = nil
        self.output = nil
      end
      
      def global?
        input == nil && output == nil
      end
      
      def round
        input.kind_of?(Integer) ? input : nil
      end
    
    end
  end
end