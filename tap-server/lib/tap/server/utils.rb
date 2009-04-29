module Tap
  class Server
    module Utils
      module_function
      
      # Generates a random integer key.
      def random_key(length)
        length = 1 if length < 1
        rand(length * 10000).to_s
      end
    end
  end
end