require 'rake'
require 'tap'

module Tap
  module Support
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
      
      def collect_tasks
        ARGV.collect! do |arg|
          next(arg) unless arg =~ /^:([a-z_\d]+)(:.*)$/
          env_pattern = $1
          
          next(arg) unless entry = env.find(:envs, env_pattern, false)
          
          mini_path, env = entry
          root_path = env.root.root
          
          if have_rakefile(root_path)
            # load sequence echos that in raw_load_rakefile
            puts "(in #{root_path})" unless options.silent
            current_global_rakefile = $rakefile
            $rakefile = @rakefile
            
            if @rakefile != ''
              namespaces = Tap::Root.split(mini_path, false).delete_if {|segment| segment.empty? }
              eval nest_namespace(%Q{load "#{File.join(root_path, @rakefile)}"}, namespaces)
            end
            
            $rakefile = current_global_rakefile
            @rakefile = nil
          else
            fail "No Rakefile found for '#{env_pattern}' (looking for: #{@rakefiles.join(', ')})"
          end
          
          mini_path + $2
        end
        
        super
      end
      
      def have_rakefile(indir=nil)
        return super() if indir == nil
        Tap::Root.indir(indir) { super() }
      end

      protected
      
      NAMESPACE_STR = %Q{
namespace(:%s) do
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

Rake.application.extend Tap::Support::Rake
Tap::Env.manifests[:rakefiles] = Tap::Support::RakeManifest

