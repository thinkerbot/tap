require 'rubygems'

module Tap
  class Env
  
    # Methods for working with {RubyGems}[http://www.rubygems.org/].
    module Gems
      module_function
    
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
        index = latest ?
          Gem.source_index.latest_specs :
          Gem.source_index.gems.collect {|(name, spec)| spec }
      
        index = index.select do |spec|
          yield(spec)
        end if block_given?
      
        index.sort
      end
    end
  end
end