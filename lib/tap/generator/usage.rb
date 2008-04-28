require 'tap/generator/options'

module Tap
  module Generator
    module Usage # :nodoc:
      include Options
      
      protected
      
      # Adapted from code in 'rails/rails_generator/scripts.rb'
      def usage_message
        usage = "\nInstalled Generators\n"
        Rails::Generator::Base.sources.each do |source|
          label = source.label.to_s.capitalize
          names = source.names
          usage << "  #{label}: #{names.join(', ')}\n" unless names.empty?
        end

        usage << <<end_blurb
        
end_blurb
        return usage
      end
    end
  end
end
