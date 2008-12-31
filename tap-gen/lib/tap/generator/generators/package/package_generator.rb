require 'shellwords'
require 'pp'

module Tap::Generator::Generators
  class PackageGenerator < Rails::Generator::NamedBase # :nodoc:
    include Shellwords
    
    attr_accessor :config, :argv, :package_file
    
    def initialize(*args)
      super(*args)    
      @destination_root  = Tap::App.instance[:root]
      @app = Tap::App.instance
  	end

    def manifest
      record do |m|
        # read the config for the current root
        default_config_file = File.expand_path( Tap::Env::DEFAULT_CONFIG_FILE )
        @config = File.exists?(default_config_file) ? File.read(default_config_file) : ""
        
        # at this point ARGV still includes the package name, 
        # ie the commands should be argument 1  
        # Note: it's important to setup argv this way, from a single argument,
        # so that options can be included in the packaged arguments:
        #   generate package raw_to_mgf "run --debug some/task"
        # vs
        #   generate package raw_to_mgf run --debug some/task
        # where '--debug' is applied to generate rather than run
        args = ARGV[1]
        raise "no command specified (see usage for more info)" unless args
        @argv = PP.singleline_pp(shellwords(args), '')
        
        @package_file = class_path.empty? ? file_name : File.join(class_path, file_name)
        filepath = "package/#{@package_file}.rb"
        m.directory File.dirname(filepath)
        m.template "package.erb", filepath
      end
    end
  end
end