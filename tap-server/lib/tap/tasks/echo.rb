module Tap
  module Tasks
    
    # ::task
    class Echo < Tap::Task
      config :key, 'default'       # a basic config
      
      config :flag_false, false, &c.flag # a flag config (false)
      config :flag_true, true, &c.flag   # a flag config (true)
      
      config :switch_false, false, &c.switch # a switch config (false)
      config :switch_true, true, &c.switch   # a switch config (true)
      
      config :string, "string", &c.string    # string
      #config :sym, :sym, &c.symbol           # sym
      config :integer, 10, &c.integer        # integer
      config :numeric, 10, &c.numeric        # numeric
      config :float, 10.0, &c.float            # float
      
      config :string_or_nil, nil, &c.string_or_nil   # string_or_nil (nil)
      #config :sym_or_nil, nil, &c.symbol_or_nil      # symbol_or_nil (nil)
      config :integer_or_nil, nil, &c.integer_or_nil # integer_or_nil (nil)
      config :number_or_nil, nil, &c.numeric_or_nil  # number_or_nil (nil)
      config :float_or_nil, nil, &c.float_or_nil     # float_or_nil (nil)
      
      #config :range, 1..10, &c.range   # range
      #config :array, [1,2,3], &c.array # array
      #config :hash, {}, &c.hash        # hash
      #config :regexp, /abc/, &c.regexp # regexp
      config :select, 3, &c.select(12,3, &c.integer) # list
      config :list_select, [3], &c.list_select(1,4,12,3, &c.integer) # list select 
      
      # 
      # 
      # config :output, $stdout, &c.io # regexp
      
      nest :nest do                # nest desc
        config :a, 'default'       # a nested config (before)
        nest :nest do              # double-nest desc
          config :key, 'default'   # a double-nested config
        end
        config :z, 'default'       # a nested config (after)
      end
      
    end
  end
end