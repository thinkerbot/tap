module Tap
  module Tasks
    
    # ::manifest
    class Echo < Tap::Task
      
      config :key, 'default', :short => 'k'   # a simple config with short
      config :flag, false, &c.flag            # a flag config
      config :falseswitch, false, &c.switch        # a --[no-]switch config
      config :trueswitch, true, &c.switch        # a --[no-]switch config
      config :num, 10, &c.integer             # integer only
      config :range, 1..10, &c.range          # range only
      config :array, [1,2,3], &c.array          # array
      config :list, [1,2,3], &c.list          # list
      config :hash, {}, &c.hash          # hash
      config :regexp, /abc/, &c.regexp          # regexp
      config :output, $stdout, &c.io         # regexp

      config :list_select, [], &c.list_select(1,2,3, &c.integer)          # selection
      config :upcase, 'default' do |value|    # custom transformation
        value.upcase
      end
      
      def process(*args)
        args = args.flatten
        args << name
        log name, args.inspect
        args
      end
    end
  end
end