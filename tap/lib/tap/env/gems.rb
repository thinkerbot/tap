require 'tap/env/path'
require 'rbconfig'

module Tap
  class Env
    
    # Methods for working with {RubyGems}[http://www.rubygems.org/].
    module Gems
      module_function
      
      CACHE_DIR = ENV['TAP_CACHE'] || '~/.tap'
      CACHE_HOME = File.expand_path("#{RbConfig::CONFIG['RUBY_INSTALL_NAME']}/#{RUBY_VERSION}", CACHE_DIR)
      GEM_PATH_FILE = File.expand_path('gemfile', CACHE_HOME)
      
      def env_files(gem_pattern)
        unless gem_pattern.kind_of?(Regexp)
          gem_pattern = Regexp.new(gem_pattern)
        end
        
        if File.exists?(GEM_PATH_FILE)
          gem_path = File.read(GEM_PATH_FILE).split(/\r?\n/)
          gem_path << __FILE__
          
          unless FileUtils.uptodate?(GEM_PATH_FILE, gem_path)
            errlog { [:info, 'gem cache is out of date'] }
            FileUtils.rm_r(CACHE_HOME)
          end
        end
        
        unless File.exists?(CACHE_HOME)
          generate_cache(CACHE_HOME, GEM_PATH_FILE)
        end
        
        Dir.glob(File.join(CACHE_HOME, '*-*')).select do |env_file|
          File.basename(env_file) =~ gem_pattern
        end
      end
      
      def errlog
        if $DEBUG || true
          $stderr.puts("%12s: %s" % yield)
        end
      end
      
      def generate_cache(cache_home, gem_path_file)
        require 'rubygems'
        
        FileUtils.mkdir_p(cache_home)
        File.open(gem_path_file, 'w') do |io|
          errlog { [:generate, gem_path_file] } 
          Gem.path.each do |gem_path|
            io.puts File.join(gem_path, 'specifications')
          end
        end
        
        visited={}
        Gem.source_index.gems.each do |(name, gemspec)|
          path_file = File.expand_path(Path::FILE, gemspec.full_gem_path)
          unless File.exists?(path_file)
            errlog { [:skip, gemspec.full_name] }
            next
          end
          
          generate_envfile(gemspec, cache_home, visited)
        end
      end
      
      def generate_envfile(gemspec, cache_home, visited)
        return visited[gemspec] if visited.has_key?(gemspec)
        
        env_file = File.expand_path(gemspec.full_name, cache_home)
        if FileUtils.uptodate?(env_file, [gemspec.full_gem_path, __FILE__])
          errlog { [:uptodate, gemspec.full_name] }
        else
          errlog { [:generate, gemspec.full_name] }
          File.open(env_file, 'w') do |io|
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
        
        visited[gemspec] = env_file
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