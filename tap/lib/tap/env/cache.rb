require 'tap/env/constant'

module Tap
  class Env
    class Cache
      class << self
        def load(cache, lib_paths)
          constants = []
          lib_paths.each do |lib_path|
            constants.concat Constant.scan(lib_path, '**/*.rb')
          end
          constants.sort!
          constants
        end
      end
    end
  end
end