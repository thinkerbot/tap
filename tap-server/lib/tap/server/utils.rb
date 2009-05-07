module Tap
  class Server
    module Utils
      module_function
      
      # Generates a random integer key.
      def random_key(length=1)
        length = 1 if length < 1
        rand(length * 10000)
      end
    end
  end
end