require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task globs for files
    #
    # Globs the input patterns for matching patterns.  Matching files are
    # returned as an array.
    #
    #   % tap run -- glob * --: dump/yaml
    #
    # A variety of filters are available as configurations.
    #
    # == Glob Expansion
    #
    # NOTE that glob patterns are normally expanded on the command line,
    # meaning the task will receive an array of files and not glob patterns.
    # Usually this doesn't make a difference in the task results, but it can
    # slow down launch times.
    #
    # To glob within the task and not the command line, quote the glob.
    #
    #   % tap run -- glob '*' --: dump/yaml
    #
    class Glob < Tap::Task
      
      config :includes, [/./], :long => :include, &c.list(&c.regexp)  # Regexp include filters
      config :excludes, [], :long => :exclude, &c.list(&c.regexp)     # Regexp exclude filters
      config :unique, true, &c.switch             # Ensure results are unique
      config :files, true, &c.switch              # Glob for files
      config :dirs, false, &c.switch              # Glob for directories
      
      def process(*patterns)
        results = []
        patterns.each do |pattern|
          Dir[pattern].each do |path|
            next if files == false && File.file?(path)
            next if dirs == false  && File.directory?(path)
            
            case path
            when *excludes
              next
            when *includes
              results << path
            end
          end
        end
        
        results.uniq! if unique
        results
      end
    end
  end
end