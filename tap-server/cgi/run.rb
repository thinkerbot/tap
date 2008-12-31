# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"

env = Tap::Env.instance

module Tap
  module Support
    module Server
      module_function
      
      def parse_schema(params)
        argh = pair_parse(params)

        parser = Parser.new
        parser.parse(argh['nodes'] || [])
        parser.parse(argh['joins'] || [])
        parser.schema
      end
      
      def pair_parse(params)
        pairs = {}
        params.each_pair do |key, values|
          next if key == nil
          key = key.chomp("%w") if key =~ /%w$/

          slot = pairs[key] ||= []
          values.each do |value|
            value = value.respond_to?(:read) ? value.read : value
            if $~ 
              slot.concat(Shellwords.shellwords(value))
            else 
              slot << value
            end
          end
        end

        UrlEncodedPairParser.new(pairs).result   
      end
    end
  end
end

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out() do
  case cgi.request_method
  when /GET/i
    schema = Tap::Support::Server.parse_schema(cgi.params).compact
    env.render('run.erb', :env => env, :schema => schema)
  
  when /POST/i
    action = cgi.params['action'][0]
    case action
    when 'add'
      index = cgi.params['index'][0].to_i - 1
      sources = cgi.params['sources'].flatten.collect {|source| source.to_i }
      targets = cgi.params['targets'].flatten.collect {|target| target.to_i }
      
      lines = []
      cgi.params['tasc'].select do |name|
        name && !name.empty?
      end.each do |name|
        index += 1
        targets << index
        lines << env.render('run/node.erb', :env => env, :node => Tap::Support::Node.new([name]), :index => index )
      end
      
      join = case
      when sources.length > 1 && targets.length == 1
        Tap::Support::Schema::Utils.format_merge(sources, targets, {})
      when sources.length == 1 && targets.length > 0
        Tap::Support::Schema::Utils.format_fork(sources, targets, {})
      else nil
      end
      
      lines << env.render('run/join.erb', :env => env, :join => join) if join
      lines.join("\n")
    
    when 'remove'

    else
      # run
      cgi.pre do
        schema = Tap::Support::Server.parse_schema(cgi.params)
        schema.compact.dump.to_yaml
        #env.build(schema)
      end
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end
