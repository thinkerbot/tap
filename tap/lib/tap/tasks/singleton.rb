require 'tap/task'

module Tap
  module Tasks
    # ::resource 
    class Singleton < Tap::Task
      class << self
        def cache
          @cache ||= {}
        end
        
        def new(*args)
          obj = super
          cache[obj.signature] ||= obj
        end
      end
      
      attr_reader :cache
      attr_reader :signature
      
      def initialize(config={}, app=Tap::App.instance)
        @signature = [config.dup, app].freeze
        super(config, app)
        reset
      end
      
      def call(input)
        cache.has_key?(input) ? cache[input] : cache[input] = super
      end
      
      def reset
        @cache = {}
      end
    end
  end
end