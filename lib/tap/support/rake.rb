require 'rake'
require 'tap'

module Tap
  module Support
    module Rake
      def self.extended(base)
        Tap::Env.instance_for(Dir.pwd).activate unless Tap::Env.instance
        base.env = Tap::Env.instance
        base.env_map = Tap::Env.instance.manifest(:envs).mini_map
      end
      
      attr_accessor :env, :env_map
      
      def collect_tasks
        ARGV.collect! do |arg|
          next(arg) unless arg =~ /^:([a-z_\d]+)(:.*)$/
          next(arg) unless path_pattern = env.find(:envs, $1)
          
          mini_path, env = env_map.find {|key, value| value == path_pattern }
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
            fail "No Rakefile found for '#{path_pattern}' (looking for: #{@rakefiles.join(', ')})"
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
