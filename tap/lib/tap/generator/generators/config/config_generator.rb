module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::ConfigGenerator::generator a config file for a task
  # 
  # Generates a new config file for a task.  The configurations, defaults, 
  # and documentation is determined from the task source file.
  class ConfigGenerator < Tap::Generator::Base
    
    # Dumps a nested configuration.
    DUMP_DELEGATES = lambda do |key, delegate, block|
      nested_delegates = delegate.default(false).delegates
      indented_dump = Configurable::Utils.dump(nested_delegates, &block).gsub(/^/, "  ")
      "#{key}:\n#{indented_dump}"
    end
    
    # Dumps configurations as YAML with documentation,
    # used when the doc config is true.
    DOC_FORMAT = lambda do |key, delegate|
      if delegate.is_nest?
        DUMP_DELEGATES[key, delegate, DOC_FORMAT]
      else
        default = delegate.default
      
        # get the description
        desc = delegate.attributes[:desc]
        doc = desc.to_s
        doc = desc.comment if doc.empty?
      
        # wrap as lines
        lines = Lazydoc::Utils.wrap(doc, 50).collect {|line| "# #{line}"}
        lines << "" unless lines.empty?
      
        # setup formatting
        leader = default == nil ? '# ' : ''
        config = {key => default}.to_yaml[5..-1]
        "#{lines.join("\n")}#{leader}#{config.strip}\n\n"
      end
    end
    
    # Dumps configurations as YAML without documentation, 
    # used when the doc config is false.
    NODOC_FORMAT = lambda do |key, delegate|
      if delegate.is_nest?
        DUMP_DELEGATES[key, delegate, NODOC_FORMAT]
      else
        default = delegate.default
      
        # setup formatting
        leader = default == nil ? '# ' : ''
        config = {key => default}.to_yaml[5..-1]
        "#{leader}#{config.strip}\n"
      end
    end
    
    config :doc, true, &c.switch        # include documentation in the config
    config :nest, false, &c.switch      # generate nested config files
    
    # Returns the active Env.instance, for looking up the task configurations.
    def env
      Tap::Env.instance
    end
    
    def manifest(m, name, config_name=name)
      # setup
      const = env.tasks.search(name) or raise "unknown task: #{name}"
      task_class = const.constantize or raise "unknown task: #{name}"
      config_file = app.filepath('config', config_name + ".yml")
      
      # generate the dumps
      dumps = Configurable::Utils.dump_file(task_class.configurations, config_file, nest, true, &format_block)
      
      # now put the dumps to the manifest
      dumps.keys.sort.each do |path|
        m.directory(File.dirname(path))
        m.file(path) do |file|
          file << dumps[path]
        end
      end
    end
    
    # A hook to set a formatting block.  By default format_blocks
    # returns DOC_FORMAT or NODOC_FORMAT as per the doc config.
    def format_block
      doc ? DOC_FORMAT : NODOC_FORMAT
    end
  end
end