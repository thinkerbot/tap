module Tap
  module Support
    module Renderer
      # Builds the specified template using the rack_env and additional
      # attributes. The rack_env is partitioned into rack-related and 
      # cgi-related hashes (all rack_env entries where the key starts
      # with 'rack' are rack-related, the others are cgi-related).
      #
      # The template is built with the following standard locals:
      #
      #   server   self
      #   cgi      the cgi-related hash
      #   rack     the rack-related hash
      #
      # Plus the attributes.
      def render(path, attributes={}) # :nodoc:
        unless template_path = search(:template, path) {|file| File.file?(file) }
          raise ArgumentError.new("no such template: #{path}")
        end

        if attributes.has_key?(:env) && attributes[:env] != self
          raise ArgumentError.new("attributes specifies env")
        end

        template(File.read(template_path), attributes.merge(:env => self))
      end

      # Builds the specified ERB template using the attributes.
      def template(template, attributes={})
        Templater.new(template, attributes).build
      end
    end
  end
end