require 'tap'
  
module Rap
  module Utils
    module_function
    
    # A helper to resolve the arguments for a task; returns the array
    # [task_name, configs, needs, arg_names].
    #
    # Adapted from Rake 0.8.3
    # Changes:
    # - no :needs support for the trailing Hash (which is now config)
    def resolve_args(args)
      task_name = args.shift
      arg_names = args
      configs = {}
      needs = []

      # resolve hash task_names, for the syntax:
      #   task :name => [dependencies]
      if task_name.is_a?(Hash)
        hash = task_name
        case hash.length
        when 0 
          task_name = nil
        when 1 
          task_name = hash.keys[0]
          needs = hash[task_name]
        else
          raise ArgumentError, "multiple task names specified: #{hash.keys.inspect}"
        end
      end

      # ensure a task name is specified
      if task_name == nil
        raise ArgumentError, "no task name specified" if args.empty?
      end

      # pop off configurations, if present, using the syntax:
      #   task :name, :one, :two, {configs...}
      if arg_names.last.is_a?(Hash)
        configs = arg_names.pop
      end

      needs = needs.respond_to?(:to_ary) ? needs.to_ary : [needs]
      needs = needs.compact.collect do |need|

        unless need.kind_of?(Class)
          # lookup or declare non-class dependencies
          name = normalize_name(need).camelize
          need = Tap::Support::Constant.constantize(name) do |base, constants|
            const = block_given? ? yield(name) : nil
            const or raise ArgumentError, "unknown task class: #{name}"
          end
        end

        unless need.ancestors.include?(Tap::Task)
          raise ArgumentError, "not a task class: #{need}"
        end

        need
      end

      [normalize_name(task_name), configs, needs, arg_names]
    end

    # helper to translate rake-style names to tap-style names, ie
    #
    #   normalize_name('nested:name')    # => "nested/name"
    #   normalize_name(:symbol)          # => "symbol"
    #
    def normalize_name(name)
      name.to_s.tr(":", "/")
    end
  end
end