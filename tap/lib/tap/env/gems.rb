require 'tap/env/path'
require 'rbconfig'

autoload(:Gem, 'rubygems')
module Tap
  class Env
    
    # Methods for working with {RubyGems}[http://www.rubygems.org/].
    module Gems
      module_function
      
      CACHE_DIR = ENV['TAP_CACHE'] || '~/.tap'
      CACHE_HOME = File.expand_path("#{RbConfig::CONFIG['RUBY_INSTALL_NAME']}/#{RUBY_VERSION}", CACHE_DIR)
      
      def env_path(dependencies)
        if dependencies.kind_of?(String)
          dependencies = dependencies.split(':')
        end
        
        env_paths = []
        dependencies.collect! do |dep|
          dep.kind_of?(String) ? dep.split(',', 2) : dep
        end.each do |(pattern, version_requirements)|
          pattern = Regexp.new("^#{pattern}$") if pattern.kind_of?(String)
          env_paths.concat env_files(pattern, version_requirements)
        end
        
        env_paths.uniq!
        env_paths
      end
      
      def env_files(pattern, version_requirements)
        dependency = Gem::Dependency.new(pattern, version_requirements)
        
        unless File.exists?(CACHE_HOME)
          FileUtils.mkdir_p(CACHE_HOME)
        end
        
        sources = {}
        Gem.source_index.search(dependency).sort.reverse_each do |spec|
          sources[spec.name] ||= spec
        end
        
        results = []
        sources.values.sort_by do |spec|
          spec.name
        end.each do |spec|
          path_file = File.expand_path(Path::FILE, spec.full_gem_path)
          unless File.exists?(path_file)
            next
          end
          
          cache_path = File.join(CACHE_HOME, spec.full_name)
          gem_path = spec.full_gem_path
          
          unless FileUtils.uptodate?(cache_path, gem_path)
            generate_envfile(spec, cache_path)
          end
          
          results << cache_path
        end
        results
      end
      
      def errlog
        if $DEBUG || true
          $stderr.puts("%12s: %s" % yield)
        end
      end
      
      def generate_envfile(gemspec, cache_path)
        errlog { [:generate, gemspec.full_name] }
        
        File.open(cache_path, 'w') do |io|
          io.puts "# Generated for #{gemspec.full_name} on #{Time.now}.  Do not edit."
          lines = Env.generate(:dir => gemspec.full_gem_path, :pathfile => File.expand_path(Path::FILE, gemspec.full_gem_path))
          
          load_paths(gemspec).flatten.each do |path|
            next unless path
            lines << "loadpath '#{Path.escape(path)}'"
          end
          
          lines.uniq!
          lines.sort!
          io << lines.join("\n")
        end
      end
      
      def load_paths(spec)
        spec.dependencies.collect do |dependency|
          unless dependency.type == :runtime
            next
          end

          unless gemspec = Gems.gemspec(dependency)
            # this error may result when a dependency has
            # been uninstalled for a particular gem
            warn "missing gem dependency: #{dependency.to_s} (#{spec.full_name})"
            next
          end
          
          gemspec.require_paths.collect do |path|
            File.expand_path(path, gemspec.full_gem_path)
          end
        end
      end
      
      # Returns the gemspec for the specified gem.  A gem version 
      # can be specified in the name, like 'gem >= 1.2'.  The gem
      # is not activated by this method.
      def gemspec(gem_name)
        return gem_name if gem_name.kind_of?(Gem::Specification)
        
        dependency = if gem_name.kind_of?(Gem::Dependency)
          gem_name
        else
          # figure the version of the gem, by default >= 0.0.0
          gem_name.to_s =~ /^([^~<=>]*)(.*)$/
          name, version = $1.strip, $2
          return nil if name.empty?
          version = Gem::Requirement.default if version.empty?
      
          # note the last gem matching the dependency requirements
          # is the latest matching gem
          Gem::Dependency.new(name, version)
        end
        
        Gem.source_index.search(dependency).last
      end
      
    end
  end
end