module Tap::Generator::Generators
  
  # :startdoc::generator a config file generator
  # 
  # Generates a new config file for a task.  The configurations, defaults, 
  # and documentation is determined from the source file.
  #
  # Configurations for other types of configurable resources may also be
  # generated.  Specify the constant attribute identifying the resource
  # using the 'type' flag.  This generates a config file for the Root
  # generator:
  #
  #   % tap generate config root --type generator
  #
  class Config < Tap::Generator::Base
    
    dump_delegates = lambda do |leader, delegate, block|
      nested_delegates = delegate.default(false).delegates
      indented_dump = Configurable::Utils.dump(nested_delegates, &block).gsub(/^/, "  ")
      "#{leader}: \n#{indented_dump}"
    end
    
    doc_format = lambda do |key, delegate|
      # get the description
      desc = delegate.attributes[:desc]
      doc = desc.to_s
      doc = desc.comment if doc.empty?
    
      # wrap as lines
      lines = Lazydoc::Utils.wrap(doc, 50).collect {|line| "# #{line}"}
      lines << "" unless lines.empty?
      
      if delegate.is_nest?
        leader = "#{lines.join("\n")}#{key}"
        DUMP_DELEGATES[leader, delegate, DOC_FORMAT]
      else
        default = delegate.default
        
        # setup formatting
        leader = default == nil ? '# ' : ''
        config = YAML.dump({key => default})[5..-1]
        "#{lines.join("\n")}#{leader}#{config.strip}\n\n"
      end
    end
    
    nodoc_format = lambda do |key, delegate|
      if delegate.is_nest?
        DUMP_DELEGATES[key, delegate, NODOC_FORMAT]
      else
        default = delegate.default
      
        # setup formatting
        leader = default == nil ? '# ' : ''
        config = YAML.dump({key => default})[5..-1]
        "#{leader}#{config.strip}\n"
      end
    end
    
    # Dumps a nested configuration.
    DUMP_DELEGATES = dump_delegates
    
    # Dumps configurations as YAML with documentation,
    # used when the doc config is true.
    DOC_FORMAT = doc_format
    
    # Dumps configurations as YAML without documentation, 
    # used when the doc config is false.
    NODOC_FORMAT = nodoc_format
    
    config :doc, true, &c.switch        # Include documentation in the config
    config :nest, false, &c.switch      # Generate nested config files
    config :blanks, true, &c.switch     # Allow generation of empty config files
    config :type, 'task'                # Specify the resource type
    
    # Lookup the named resource.  Lookup happens through the active Env 
    # instance, specifically using:
    #
    #   Env.instance[type][name]
    #
    # Raises an error if the name cannot be resolved to a resource.
    def lookup(name)
      env = Tap::Env.instance
      env[type][name] or raise "unknown #{type}: #{name}"
    end
    
    def manifest(m, name, config_name=nil)
      # setup
      tasc = lookup(name)
      config_name ||= tasc.to_s.underscore
      config_file = path('config', config_name)
      config_file += ".yml" if File.extname(config_file).empty?
      
      # generate the dumps
      dumps = Configurable::Utils.dump_file(
        tasc.configurations,
        config_file, 
        nest, 
        true, 
        &format_block)
      
      # now put the dumps to the manifest
      m.directory(path('config'))
      
      dumps.each do |path, content|
        next if content.empty? && !blanks
        m.file(path) do |file|
          file << content
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