require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def options
    options = {
      :tapfile   => ENV['TAPFILE']   || 'tapfile',
      :gems      => ENV['TAP_GEMS']  || '.',
      :path      => ENV['TAP_PATH']  || '.',
      :tapenv    => ENV['TAPENV']    || 'tapenv',
      :taprc     => ENV['TAPRC']     || '~/.taprc:taprc',
      :tap_cache => ENV['TAP_CACHE'] || '~/.tap',
      :debug     => ENV['TAP_DEBUG']
    }
    options
  end
  
  def setup(options=self.options)
    env = Env.new
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    App.instance = app
    
    def options.process(key, default=nil)
      value = self[key] || default
      if self[:debug] == 'true'
        $stderr.puts "%12s: %s" % [key, value]
      end
      value && block_given? ? yield(value) : nil
    end
    
    if options[:debug] == 'true'
      options.process(:ruby, "#{RbConfig::CONFIG['RUBY_INSTALL_NAME']}-#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})")
      options.process(:tap, VERSION)
    end
    
    options.process(:tapfile) do |tapfile_path|
      Env::Path.split(tapfile_path).each do |tapfile|
        load(tapfile) if File.file?(tapfile)
      end
    end
    
    options.process(:gems) do |gems|
      cache_dir = options[:tap_cache]
      cache_dir = Dir.tmpdir if cache_dir.to_s.strip.empty?
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
    
    app
  end
end