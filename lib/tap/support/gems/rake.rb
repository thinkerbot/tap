require 'rake'
require 'tap'

module Tap
  module Support
    module Gems
      class RakeManifest < Support::Manifest
        def initialize(env)
          @env = env
          rake = ::Rake.application
          super(rake.have_rakefile(env.root.root) ? [rake.instance_variable_get(:@rakefile)] : [])
        end
      end
    
      module Rake

        def self.extended(base)
          Tap::Env.instance_for(Dir.pwd).activate unless Tap::Env.instance
          base.env = Tap::Env.instance
        end
      
        attr_accessor :env
       
        def collect_tasks(*args)
          # a little song and dance for compliance with
          # rake pre- and post-0.8.2
          argv = args.empty? ? ARGV : args[0]
          argv.collect! do |arg|
            next(arg) unless arg =~ /^:([a-z_\d]+):(.*)$/
            env_pattern = $1
            rake_task = $2
          
            next(arg) unless entry = env.find(:envs, env_pattern, false)
          
            mini_path, env = entry
            root_path = env.root.root
          
            if have_rakefile(root_path)
              # load sequence echos that in raw_load_rakefile
              puts "(in #{root_path})" unless options.silent
              current_global_rakefile = $rakefile
              $rakefile = @rakefile
            
              namespaces = Tap::Root.split(mini_path, false).delete_if do |segment| 
                segment.empty?
              end
            
              #if @rakefile != ''
              eval nest_namespace(%Q{load "#{File.join(root_path, @rakefile)}"}, namespaces.dup)
              #end
            
              $rakefile = current_global_rakefile
              @rakefile = nil
            
              namespaces << rake_task
              namespaces.join(":")
            else
              fail "No Rakefile found for '#{env_pattern}' (looking for: #{@rakefiles.join(', ')})"
            end
          end
          
          super
        end
      
        def have_rakefile(dir=nil)
          return super() if dir == nil
          Tap::Root.chdir(dir) { super() }
        end

        protected
      
        NAMESPACE_STR = %Q{
namespace(:'%s') do
  %s
end
}.strip
      
        def nest_namespace(nest_str, namespaces)
          return nest_str if namespaces.empty?
        
          NAMESPACE_STR % [
            namespaces.shift, 
            namespaces.empty? ? nest_str : nest_namespace(nest_str, namespaces)
          ]
        end
      end
    end
  end
end

Rake.application.extend Tap::Support::Gems::Rake
Tap::Env.manifest(:rakefiles) do |env|
  Tap::Support::Gems::RakeManifest.new(env)
end
