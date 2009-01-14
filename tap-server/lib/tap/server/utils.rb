require "#{File.dirname(__FILE__)}/../../../vendor/url_encoded_pair_parser"

module Tap
  module Server
    module Utils
      module_function
      
      def parse_schema(params)
        argh = pair_parse(params)

        parser = Support::Parser.new
        parser.parse(argh['nodes'] || [])
        parser.parse(argh['joins'] || [])
        parser.schema
      end
      
      # UrlEncodedPairParser.parse, but also doing the following:
      #
      # * reads io values (ie multipart-form data)
      # * keys ending in %w indicate a shellwords argument; values
      #   are parsed using shellwords and concatenated to other
      #   arguments for key
      #
      # Returns an argh.  The schema-related entries will be 'nodes' and
      # 'joins', but other entries may be present (such as 'action') that
      # dictate what gets done with the params.
      def pair_parse(params)
        pairs = {}
        params.each_pair do |key, values|
          next if key == nil
          key = key.chomp("%w") if key =~ /%w$/

          resolved_values = pairs[key] ||= []
          values.each do |value|
            value = value.respond_to?(:read) ? value.read : value
            
            # $~ indicates if key matches shellwords pattern
            if $~ 
              resolved_values.concat(Shellwords.shellwords(value))
            else 
              resolved_values << value
            end
          end
        end

        UrlEncodedPairParser.new(pairs).result   
      end
    end
  end
end