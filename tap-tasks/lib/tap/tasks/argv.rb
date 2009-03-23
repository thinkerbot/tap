module Tap
  module Tasks
    # :startdoc::manifest provides a handle to ARGV
    #
    # Simply returns ARGV.  This task can be a useful hook when executing
    # saved workflows via run (given that all arguments after the workflow
    # file are preserved in ARGV).
    #
    #   # [workflow.yml]
    #   # - - argv
    #   # - - dump/yaml
    #   # - 0[1]
    #
    #   % tap run -w workflow.yml a b c
    #   ---
    #   - a
    #   - b
    #   - c
    #   
    class Argv < Tap::Task
      
      # Simply returns ARGV.
      def process
        ARGV
      end
    end
  end
end