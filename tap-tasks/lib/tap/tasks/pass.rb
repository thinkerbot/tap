require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task pass an input as the output
    #
    # Pass simply passes back the input it is given.  Pass is useful for
    # managing a queue when each member of an array is synchronized with a
    # processed result.
    #
    #   [tapfile]
    #   task :reverse do |config, str|
    #     str.reverse
    #   end
    #
    #   % tap load/yaml '[abc, xyz]' -:i pass -: reverse - inspect - sync 1,2 3
    #   ["abc", "cba"]
    #   ["xyz", "zyx"]
    #
    class Pass < Tap::Task
      def call(input)
        process(input)
      end
      
      def process(input)
        input
      end
    end
  end
end