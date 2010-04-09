require 'tap/env/path'

autoload(:Gem, 'rubygems')
autoload(:RbConfig, 'rbconfig')
module Tap
  class Env
    class Cache
      attr_reader :cache_home
      
      def initialize(dir=Dir.pwd, debug=false)
        @cache_home = File.expand_path("#{RbConfig::CONFIG['RUBY_INSTALL_NAME']}/#{RUBY_VERSION}", dir)
        @debug = debug
      end
      
      def select(dependencies)
        if dependencies.kind_of?(String)
          dependencies = dependencies.split(':')
        end
        
        paths = []
        dependencies.collect! do |dep|
          dep.kind_of?(String) ? dep.split(',', 2) : dep
        end.each do |(pattern, version_requirements)|
          pattern = Regexp.new(pattern) if pattern.kind_of?(String)
          paths.concat search(pattern, version_requirements)
        end
        
        paths.uniq!
        paths
      end
      
      def search(pattern, version_requirements)
        dependency = Gem::Dependency.new(pattern, version_requirements)
        
        sources = {}
        Gem.source_index.search(dependency).sort_by do |spec|
          spec.version
        end.reverse_each do |spec|
          sources[spec.name] ||= spec
        end
        
        paths = []
        sources.values.sort_by do |spec|
          spec.name
        end.each do |spec|
          unless File.exists? File.expand_path(Path::FILE, spec.full_gem_path)
            next
          end
          
          path = File.join(cache_home, spec.full_name)
          gem_path = spec.full_gem_path
          
          unless FileUtils.uptodate?(path, [gem_path, __FILE__])
            unless File.exists?(cache_home)
              FileUtils.mkdir_p(cache_home)
            end
            
            if @debug 
              $stderr.puts(App::DEFAULT_LOGGER_FORMAT % [nil, :generate, spec.full_name])
            end
            
            File.open(path, 'w') do |io|
              io << generate(spec)
            end
          end
          
          paths << path
        end
        
        paths
      end
      
      def generate(spec)
        lines = Env.generate(
          :dir => spec.full_gem_path, 
          :pathfile => File.expand_path(Path::FILE, spec.full_gem_path),
          :load_paths => false)
        
        lines.unshift "# Generated for #{spec.full_name} on #{Time.now}.  Do not edit."
        lines << "activate #{spec.name} #{spec.version}"
        lines.uniq!
        lines.sort!
        lines.join("\n")
      end
    end
  end
end