require 'rap/declarations'
require 'rubygems/specification'
require 'thread'

module Rap
  module Tasks
    class GemTask < DeclarationTask
      config :gemspec, nil
      
      def spec_file
        return gemspec if gemspec
        
        pwd = Dir.pwd
        base = File.basename(pwd)
        File.join(pwd, "#{base}.gemspec")
      end
      
      def spec
        path = spec_file
        data = File.read(spec_file)
        spec = nil
        Thread.new { spec = eval("$SAFE = 3\n#{data}", BINDING, path) }.join
        spec
      end
    end
  end
end

# get the binding out here so that Gem
# resolves to the RubyGems Gem module
Rap::Tasks::GemTask::BINDING = binding