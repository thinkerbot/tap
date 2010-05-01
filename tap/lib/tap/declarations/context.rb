module Tap
  module Declarations
    class Context
      include Declarations
      include Tap::Utils
      
      attr_reader :app
      
      def initialize(app, ns=nil)
        @app = app
        initialize_declare
        namespace(ns)
      end
      
      # Runs the command with system and raises an error if the command
      # fails.
      def sh(*cmd)
        app.log :sh, cmd.join(' ')
        system(*cmd) or raise "Command failed with status (#{$?.exitstatus}): [#{cmd.join(' ')}]"
      end
      
      def method_missing(sym, *args, &block)
        app.send(sym, *args, &block)
      end
    end
  end
end