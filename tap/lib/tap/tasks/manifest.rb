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
        
        lines = []
        indent = types.length > 1 ? '  ' : nil
        types.each do |type|
          if indent
            lines << "#{type}:"
          end
          
          constants.each do |constant|
            next unless constant.types.include?(type)
            lines << [indent, paths[constant], describe(constant, type)]
          end
        end
        
        format = "%s%-#{max_width(lines)}s # %s"
        lines.collect! {|line| line.kind_of?(Array) ? (format % line) : line }
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
      
      def max_width(lines)
        max = lines.collect {|line| line.kind_of?(Array) ? line.at(1).length : 0 }.max
        max < 20 ? 20 : max
      end
    end 
  end
end