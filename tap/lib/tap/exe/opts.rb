module Tap
  module Exe
    class Opts
      class << self
        def parse(argv=ARGV)
          parse!(argv.dup)
        end
        
        def parse!(argv=ARGV)
          parser = ConfigParser.new
          parser.separator ""
          parser.separator "options:"
          parser.add(configurations)
          parser.parse!(argv)
          
          opts = new(parser.config)
          
          if block_given?
            opts.set! { yield(parser) }
          end
          
          opts
        end
      end
      
      include Configurable
      
      config :chdir, false, :short => :C                # cd to directory, before execution
      config :debug, false, :short => :d, &c.flag       # set debugging flags (set $DEBUG to true)
      config :load_paths, [], :long => :load_path, :short => :I, &c.list     # specify $LOAD_PATH directory
      config :requires, [], :long => :require, :short => :r, &c.list         # require the file
      config :help, false, :short => :h, &c.flag        # show help
      
      def initialize(config={})
        initialize_config(config)
      end
      
      def set!
        yield if help
        
        Dir.chdir(chdir) if chdir
        $DEBUG = true if debug
        
        load_paths.reverse_each do |load_path|
          $LOAD_PATH.unshift(load_path)
        end
        
        requires.reverse_each do |path|
          require path
        end
        
        self
      end
    end
  end
end