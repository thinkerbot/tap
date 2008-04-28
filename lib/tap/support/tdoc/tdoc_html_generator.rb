require 'rdoc/generators/html_generator'

# Defines a specialized generator so it can be called for using a --fmt option.
class TDocHTMLGenerator < Generators::HTMLGenerator  # :nodoc:
end

module Generators # :nodoc:
  const_set(:RubyToken, RDoc::RubyToken)

  class HtmlClass < ContextUser # :nodoc:
    alias tdoc_original_value_hash value_hash
    
    def value_hash
      # split attributes into configurations and regular attributes
      configurations, attributes = @context.attributes.partition do |attribute|
        attribute.kind_of?(Tap::Support::TDoc::ConfigAttr)
      end
      
      # set the context attributes to JUST the regular 
      # attributes and process as usual.
      @context.attributes.clear.concat attributes
      values = tdoc_original_value_hash
      
      # set the context attributes to the configurations
      # and echo the regular processing to produce a list
      # of configurations
      @context.attributes.clear.concat configurations
      @context.sections.each_with_index do |section, i|
        secdata = values["sections"][i]
 
        al = build_attribute_list(section)
        secdata["configurations"] = al unless al.empty?
      end 

      values
    end
  end
end