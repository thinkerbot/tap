module Tap
  class App
    # The constants defining the possible App states.  
    module State
      READY = 0
      RUN = 1
      STOP = 2
      TERMINATE = 3
      
      module_function
      
      # Returns a string corresponding to the input state value.  
      # Returns nil for unknown states.
      #
      #   State.state_str(0)        # => 'READY'
      #   State.state_str(12)       # => nil
      def state_str(state)
        constants.inject(nil) {|str, s| const_get(s) == state ? s.to_s : str}
      end
    end
  end
end