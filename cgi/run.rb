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
      
      def pair_parse(params)
        pairs = {}
        params.each_pair do |key, values|
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
    tascs = cgi.params['tasc'].collect do |name|
      env.tasks.search(name).constantize
    end
    
    env.render('run.erb', :env => env, :tascs => tascs )

  when /POST/i
    action = cgi.params['action'][0]
    case action
    when 'add'
      index = cgi.params['index'][0].to_i - 1
      sources = cgi.params['sources'].flatten.collect {|source| source.to_i }
      targets = cgi.params['targets'].flatten.collect {|target| target.to_i }
      
      cgi.params['tasc'].collect do |name|
        index += 1
        targets << index
        tasc = env.tasks.search(name).constantize
        env.render('run/task.erb', :tasc => tasc, :index => index )
      end.join("\n")
    
    when 'remove'
    when 'update'
    else
      raise ArgumentError, "unknown POST action: #{action}"
      # argh = Tap::Support::Server.pair_parse(cgi.params)
      # Tap::Support::Schema.parse(argh['schema']).dump.to_yaml
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end
