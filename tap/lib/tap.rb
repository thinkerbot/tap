require 'tap/declarations'
require 'tap/version'

module Tap
  module_function
  
  def options
    options = {
      :tapfile   => ENV['TAPFILE'],
      :gems      => ENV['TAP_GEMS'],
      :path      => ENV['TAP_PATH'],
      :tapenv    => ENV['TAPENV'],
      :taprc     => ENV['TAPRC'],
      :tap_cache => ENV['TAP_CACHE'],
      :debug     => ENV['TAP_DEBUG']
    }
    options
  end
  
  def setup(options=self.options)
    env = Env.new
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    App.current = app
    
    def options.process(key, default=nil)
      value = self[key] || default
      if self[:debug] == 'true'
        $stderr.puts(App::DEFAULT_LOGGER_FORMAT % [' ', nil, key, value])
      end
      value && block_given? ? yield(value) : nil
    end
    
    if options[:debug] == 'true'
      options.process(:ruby, "#{RbConfig::CONFIG['RUBY_INSTALL_NAME']}-#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})")
      options.process(:tap, VERSION)
      app.debug = true
      app.verbose = true
    end
    
    options.process(:gems) do |gems|
      cache_dir = options[:tap_cache]
      
      if cache_dir.to_s.strip.empty?
        require 'tmpdir'
        cache_dir = Dir.tmpdir
      end
      
      env.signal(:load).call Env::Cache.new(cache_dir, options[:debug]).select(gems)
    end
    
    options.process(:path) do |path|
      Env::Path.split(path).each {|dir| env.auto(:dir => dir) }
    end
    
    options.process(:tapenv) do |tapenv_path|
      env.signal(:load).call Env::Path.split(tapenv_path)
    end
    
    options.process(:taprc) do |taprc_path|
      app.signal(:load).call Env::Path.split(taprc_path)
    end
    
    options.process(:tapfile) do |tapfile_path|
      Env::Path.split(tapfile_path).each do |tapfile|
        next unless File.file?(tapfile)
        Declarations::Context.new(app, File.basename(tapfile)).instance_eval(File.read(tapfile), tapfile, 1)
      end
    end
    
    app
  end
end