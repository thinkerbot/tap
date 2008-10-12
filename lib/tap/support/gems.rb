require 'rubygems'

module Tap
  module Support
    
    # Methods for working with {RubyGems}[http://www.rubygems.org/] 
    # and other gems frequently used by Tap.
    module Gems
      module_function

      # Returns the gemspec for the specified gem.  A gem version 
      # can be specified in the name, like 'gem >= 1.2'.  The gem 
      # will be activated using +gem+ if necessary.
      def gemspec(gem_name)
        return gem_name if gem_name.kind_of?(Gem::Specification)
        
        # figure the version of the gem, by default >= 0.0.0
        gem_name.to_s =~ /^([^<=>]*)(.*)$/
        name, version = $1.strip, $2
        version = ">= 0.0.0" if version.empty?
        
        return nil if name.empty?
        
        # load the gem and get the spec
        gem(name, version)
        Gem.loaded_specs[name]
      end
      
      # Selects gem specs for which the block returns true.  If
      # latest is specified, only the latest version of each
      # gem will be passed to the block.
      def select_gems(latest=true)
        index = latest ?
          Gem.source_index.latest_specs :
          Gem.source_index.gems.collect {|(name, spec)| spec }
        
        index.select do |spec|
          yield(spec)
        end.sort
      end
    end
  end
end