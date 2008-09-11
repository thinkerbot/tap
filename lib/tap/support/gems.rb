# This quick-require of rubygems causes Gem::SpecFetcher to be autoloaded.  
# In general Gem::SpecFetcher will not be needed, and it's inclusion 
# accounts for > 1/2 the require time for rubygems.  A patch has been 
# submitted; pending it's acceptance this will not be needed.
$" << 'rubygems/spec_fetcher.rb'
require 'rubygems'
$".delete('rubygems/spec_fetcher.rb')
module Gem
  autoload(:SpecFetcher, 'rubygems/spec_fetcher')
end

module Tap
  module Support
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