module Tap
  module Test
    
    # Provides a method for case-insensitive access to the ENV variables
    module EnvVars
      
      # Access to the case-insensitive ENV variables.  Raises an error
      # if multiple case-insensitive values are defined in ENV.
      def env(type)
        type = type.downcase
        
        # ruby 1.9 returns a hash instead of an array
        selected = ENV.select {|key, value| key.downcase == type}.to_a
        
        case selected.length
        when 0 then nil
        when 1 then selected[0][1]
        else
          raise "Multiple env values for '#{type}'" 
        end
      end
      
      # Returns true if the env_var(var) is set and matches /^true%/i
      def env_true?(var)
        env(var) && env(var) =~ /^true$/i
      end
    end
  end
end