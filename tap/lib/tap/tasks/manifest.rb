require 'tap/tasks/dump'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Manifest < Dump
      
      config :all, false, :short => :a, &c.flag
      config :show, 'summary', &c.select('summary', 'name', 'path')
      config :types, ['task', 'join', 'middleware'], 
        :long => :type, :short => :t, 
        &c.list(&c.string)
      
      def call(input)
        process manifest(*input)
      end
      
      def manifest(*filters)
        constants = filter(app.env.constants, filters)
        
        paths = minimap(constants)
        constants = constants.sort_by {|constant| paths[constant] }
        
        descriptions = {}
        selected_paths = []
        types.each do |type|
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
        types.each do |type|
          next unless descriptions.has_key?(type)
          
          lines << "#{type}:"
          descriptions[type].each do |description|
            lines << (format % description)
          end
        end
        
        if lines.empty?
          lines << "(no constants match criteria)"
        end
        
        lines.join("\n")
      end
      
      def filter(constants, filters)
        return constants if filters.empty?
        
        method_name = all ? :all? : :any?
        filters.collect! {|filter| Regexp.new(filter) }
        constants = constants.select do |constant|
          filters.send(method_name) do |filter|
            constant.path =~ filter
          end
        end
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
        case show
        when 'summary' then constant.types[type]
        when 'name'    then constant.const_name
        when 'path'    then constant.require_paths.join(',')
        end
      end
      
      def max_width(paths)
        max = paths.collect {|path| path.length }.max
        max.nil? || max < 20 ? 20 : max
      end
    end 
  end
end