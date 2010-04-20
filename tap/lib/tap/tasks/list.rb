require 'tap/tasks/dump'

module Tap
  module Tasks
    # :startdoc::task list resources
    #
    # Prints a list of resources registered with the application env. Any of
    # the resources may be used in a workflow.  A list of filters may be used
    # to limit the output; each is converted to a regexp and can match any
    # part of the resource (path, class, desc).
    #
    #   % tap list join gate
    #   join:
    #     gate                 # collects results before the join
    #
    # The configurations can be used to switch the resource description.  By
    # default env only lists resources registered as a task, join, or
    # middleware.
    #
    #   % tap list join gate --class --full
    #   join:
    #     /tap/joins/gate      # Tap::Joins::Gate
    #
    class List < Dump
      
      config :all, false, :short => :a, &c.flag       # Shows all types
      config :types, ['task', 'join', 'middleware'],
        :long => :type,
        :short => :t,
        :reader => false,
        &c.list(&c.string)                            # List types to show
        
      config :full, false, :short => :f, &c.flag      # Show full paths
      config :path, false, :short => :p, &c.flag      # Show require path
      config :clas, false, :long => :class,
        :short => :c, &c.flag                         # Show class
      
      def call(input)
        process manifest(*input).join("\n")
      end
      
      def basis
        app.env.constants
      end
      
      def types
        return @types unless all
        
        types = []
        app.env.constants.each do |constant|
          types.concat constant.types.keys
        end
        types.uniq!
        types.sort!
        types
      end
      
      def manifest(*filters)
        constants = filter(basis, filters)
        
        paths = full ? fullmap(constants) : minimap(constants)
        constants = constants.sort_by {|constant| paths[constant] }
        
        descriptions = {}
        selected_paths = []
        selected_types = types
        
        selected_types.each do |type|
          lines = []
          constants.each do |constant|
            next unless constant.types.include?(type)
            
            path = paths[constant]
            selected_paths << path
            lines << [path, describe(constant, type)]
          end
          
          descriptions[type] = lines unless lines.empty?
        end
        
        format = "  %-#{max_width(selected_paths)}s # %s"
        
        lines = []
        selected_types.each do |type|
          next unless descriptions.has_key?(type)
          
          lines << "#{type}:"
          descriptions[type].each do |description|
            lines << (format % description)
          end
        end
        
        if lines.empty?
          lines << "(no constants match criteria)"
        end
        
        lines
      end
      
      def filter(constants, filters)
        return constants if filters.empty?
        
        filters.collect! {|filter| Regexp.new(filter) }
        constants = constants.select do |constant|
          filters.all? do |filter|
            constant.path =~ filter
          end
        end
      end
      
      def fullmap(constants)
        paths = {}
        constants.each {|constant| paths[constant] = constant.path }
        paths
      end
      
      def minimap(constants)
        paths = {}
        constants.each do |constant|
          paths[constant] = split(constant.path)
        end
        
        minimap = {}
        queue = constants.dup
        while !queue.empty?
          next_queue = []
          queue.each do |constant|
            path = paths[constant].shift
            
            if current = minimap[path]
              next_queue << current unless current == :skip
              next_queue << constant
              minimap[path] = :skip
            else
              minimap[path] = constant
            end
          end
          
          queue = next_queue
        end
        
        minimap.delete_if {|path, constant| constant == :skip }.invert
      end
      
      def split(path)
        splits = []
        current = nil
        path.split('/').reverse_each do |split|
          current = current ? File.join(split, current) : split
          splits << current
        end
        splits
      end
      
      def describe(constant, type)
        case
        when clas 
          constant.const_name
          
        when path
          require_paths = constant.require_paths
          require_paths = require_paths.collect do |path|
            File.join(load_path(path), path)
          end if full
          require_paths.join(',')
          
        else 
          constant.types[type]
        end
      end
      
      def load_path(path)
        $:.find do |load_path|
          File.exists?(File.join(load_path, path))
        end || '?'
      end
      
      def max_width(paths)
        max = paths.collect {|path| path.length }.max
        max.nil? || max < 20 ? 20 : max
      end
    end 
  end
end