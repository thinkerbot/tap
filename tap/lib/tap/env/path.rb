module Tap
  class Env
    class Path
      class << self
        def split(str, dir=Dir.pwd)
          paths = str.kind_of?(String) ? str.split(':') : str
          paths.collect! {|path| File.expand_path(path, dir) }
          paths.uniq!
          paths
        end
      end
      
      attr_reader :base
      attr_reader :map
      
      def initialize(base, map={})
        @base = File.expand_path(base)
        @map = Hash.new do |hash, type|
          hash[type] = [File.expand_path(type.to_s, @base)]
        end
        
        map.each_pair do |type, paths|
          paths = [paths] unless paths.kind_of?(Array)
          @map[type] = paths.collect {|path| File.expand_path(path, @base) }
        end
      end
      
      def [](type)
        map[type]
      end
      
      def to_s
        base
      end
    end
  end
end