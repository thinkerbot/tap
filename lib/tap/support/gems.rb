autoload(:Gem, 'rubygems')

module Tap
  module Support
    module Gems
      module_function
      
      # Finds the home directory for the user (method taken from Rubygems).
      def find_home
        ['HOME', 'USERPROFILE'].each do |homekey|
          return ENV[homekey] if ENV[homekey]
        end

        if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
          return "#{ENV['HOMEDRIVE']}:#{ENV['HOMEPATH']}"
        end

        begin
          File.expand_path("~")
        rescue
          if File::ALT_SEPARATOR then
              "C:/"
          else
              "/"
          end
        end
      end

      # The home directory for the user.
      def user_home
        @user_home ||= find_home
      end
      
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