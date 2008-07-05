require 'active_support'
require 'rails_generator'
require 'tap/generator/options'
require 'tap/generator/usage'

module Tap
  # stub module definition so generators can use 'module Tap::Generator::Generators' 
  module Generator # :nodoc:
    module Generators  # :nodoc:
    end
  end
end
      
# These modifications are to make the rails generators work for Tap
module Rails # :nodoc:
  module Generator # :nodoc:  
    class Base # :nodoc:
      include Tap::Generator::Options
      
      # Used to discover generators within tap.  Adapted from code
      # in 'rails/rails_generator/lookup.rb'
      def self.use_tap_sources!
        reset_sources
        sources << PathSource.new(:builtin, "#{File.dirname(__FILE__)}/generator/generators")
        
        Tap::Env.instance.config['generator_paths'].each do |path|
          sources << PathSource.new(:builtin, path)
        end
      end
    end
    
    class NamedBase < Base # :nodoc:
      attr_reader :class_name_without_nesting
    end
    
    module Commands # :nodoc:
      class Create # :nodoc:
        
        #--
        # Adds a template_option to nest classes, so that "Some::ClassName" can be nested
        #
        #   module Some
        #     class ClassName
        #     end
        #   end
        #
        # rather than
        # 
        #   class Some::ClassName
        #   end
        #
        # The problem is that with the latter representation, errors can be raised if 'Some' 
        # has not already been defined as a module.
        #++
        def template(relative_source, relative_destination, template_options = {})
          file(relative_source, relative_destination, template_options) do |file|
            # Evaluate any assignments in a temporary, throwaway binding.
            vars = template_options[:assigns] || {}
            b = binding
            vars.each { |k,v| eval "#{k} = vars[:#{k}] || vars['#{k}']", b }

            # Render the source file with the temporary binding.
            content = ERB.new(file.read, nil, '-').result(b)
            
            # add nesting with two-space indentation
            if template_options.has_key?(:class_nesting)
              class_nesting = template_options[:class_nesting]
              
              nestings = class_nesting.split(/::/)
              lines = content.split(/\r?\n/)
   
              depth = nestings.length
              lines.collect! {|line| "  " * depth + line}
              
              nestings.reverse_each do |mod_name|
                depth -= 1
                lines.unshift("  " * depth + "module #{mod_name}")
                lines << ("  " * depth + "end")
              end
              
              content = lines.join("\n")
            end
            
            content
          end
        end
        
      end
    end
  end
end

