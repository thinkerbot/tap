module Tap
  module Generator
    module Helpers
      attr_reader :helper_registry
    
      def helpers
        return @helpers if @helpers
      
        helpers = []
        ancestors.each do |ancestor|
          next unless ancestor.kind_of?(Helpers)
          helpers.concat ancestor.helper_registry
        end
      
        helpers
      end
    
      def cache_helpers(on=true)
        @helpers = nil
        @helpers = self.helpers if on
      end
    
      protected
    
      def helper(const_name='helper', &block)
        helper = Module.new(&block)
        const_set(const_name.to_s.camelize, helper) if const_name
        helper_registry << helper
        helper
      end
    
      private
    
      def self.initialize(base)
        base.instance_variable_set(:@helper_registry, [])
        base.instance_variable_set(:@helpers, nil)
      end
    
      def self.extended(base)
        Helpers.initialize(base)
      end
    
      def inherited(base)
        super
        Helpers.initialize(base)
      end
    end
  end
end