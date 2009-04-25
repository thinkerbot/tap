require 'tap/task'

module Tap
  module Tasks
    # :startdoc::manifest globs for files
    #
    # Globs the input patterns for matching patterns.  Matching files are
    # returned as an array.
    class Glob < Tap::Task
      
      config :filters, [], &c.list(&c.regexp)     # a regexp filter of test files
      config :unique, true, &c.switch             # ensure results are unique
      config :files, true, &c.switch              # glob for files
      config :dirs, false, &c.switch              # glob for directories
      
      # Simply returns ARGV.
      def process(*patterns)
        results = []
        patterns.each do |pattern|
          Dir[pattern].each do |path|
            next if !files && File.file?(path)
            next if !dirs && File.directory?(path)
            
            case path
            when *filters then next
            else results << path
            end
          end
        end
        
        results.uniq! if unique
        results
      end
    end
  end
end