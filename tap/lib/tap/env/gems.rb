require 'rubygems'

module Tap
  class Env
  
    # Methods for working with {RubyGems}[http://www.rubygems.org/].
    module Gems
      module_function
      
      def env_path(gem_name)
        
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
    
      # Selects gem specs for which the block returns true.  If
      # latest is specified, only the latest version of each
      # gem will be passed to the block.
      def select_gems(latest=true)
        specs = latest ?
          Gem.source_index.latest_specs :
          Gem.source_index.gems.collect {|(name, spec)| spec }
        
        # this song and dance is to ensure that specs are sorted
        # by name (ascending) then version (descending) so that
        # the latest version of a spec appears first
        specs_by_name = {}
        specs.each do |spec|
          next unless !block_given? || yield(spec) 
          (specs_by_name[spec.name] ||= []) << spec
        end
        
        specs = []
        specs_by_name.keys.sort.each do |name|
          specs_by_name[name].sort_by do |spec| 
            spec.version
          end.reverse_each do |spec|
            specs << spec
          end
        end
        
        specs
      end
    end
  end
end