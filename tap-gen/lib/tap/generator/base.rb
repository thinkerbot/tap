require 'tap/task'
require 'tap/templater'
require 'tap/generator/manifest'
require 'tap/generator/arguments'
require 'tap/generator/generate'
require 'tap/generator/destroy'

module Tap
  module Generator
    
    # :startdoc:::-
    # Base provides the basic structure of a generator and custom generators
    # inherit from it.  Base is patterned after the {Ruby on Rails}[http://rubyonrails.org/] 
    # generators, but obviously takes on all the advantages of Tasks.
    #
    # === Usage
    #
    # Tap generators define a manifest method that defines what files and
    # directories are created by the generator.  Then, at execution time,
    # a mixin with the appropriate funtion (ie Generate or Destroy) is 
    # overlaid to figure out how to roll those actions forward or backwards.
    #
    # Generators are identified using the ::generator flag rather than ::task,
    # so that generators are available to the generate/destroy commands and
    # not run.
    #
    # Typically, generators live in a directory structure like this:
    #
    #   root
    #   |- lib
    #   |   `- sample.rb
    #   |
    #   `- templates
    #       `- sample
    #           `- template_file.erb
    #
    # Tap generators keep templates out of lib and under templates, in a
    # directory is named after the generator class.  Generators themselves
    # take the form:
    #
    #   [sample.rb]
    #   require 'tap/generator/base'
    #
    #   # ::generator generates a directory, and two files
    #   #
    #   # An extended description of the
    #   # generator goes here...
    #   #
    #   class Sample < Tap::Generator::Base
    #
    #     config :key, 'value'       # a sample config
    #
    #     def manifest(m, *args)
    #       # make a directory
    #       m.directory('path/to/dir')
    #
    #       # make a file
    #       m.file('path/to/file.txt') do |file|
    #         file << "some content"
    #       end
    #
    #       # template a file
    #       m.template('path/to/result.txt', 'template_file.erb', config.to_hash)
    #     end
    #   end
    #
    # The arguments that a generator receives are specified by manifest (minus
    # the 'm' argument which is standard) rather than process. Creating
    # directories and files is straightforward, as above.  Template renders the
    # erb source file using attributes specified in the last argument; in the
    # example template uses the generator configurations.
    #
    # :startdoc:::+
    class Base < Tap::Task
      lazy_attr :manifest, 'generator'
      lazy_attr :args, :manifest
      lazy_register :manifest, Arguments
      
      config_attr :destination_root, nil,     # The destination root directory
        :long => :destination,
        :short => :d do |root|
        root ||= default_destination_root
        @destination_root = root.kind_of?(Root) ? root : Root.new(root)
      end
      
      config_attr :template_root, nil,        # The template root directory
        :long => :template,
        :short => :t do |root|
        root ||= default_template_root
        @template_root = root.kind_of?(Root) ? root : Root.new(root)
      end
      
      config :pretend, false, &c.flag         # Run but rollback any changes.
      config :force, false, &c.flag           # Overwrite files that already exist.
      config :skip, false, &c.flag            # Skip files that already exist.
      
      signal :set                             # Set this generator to generate or destroy
      
      # The IO used to pull prompt inputs (default: $stdin)
      attr_accessor :prompt_in
      
      # The IO used to prompt users for input (default: $stdout)
      attr_accessor :prompt_out
      
      def initialize(config={}, app=Tap::App.instance)
        super
        @prompt_in = $stdin
        @prompt_out = $stdout
      end
      
      def set(module_name)
        extend app.env.constant(module_name)
        self
      end
      
      # Builds the manifest, then executes the actions of the manifest.
      # Process returns the results of iterate, which normally will be
      # an array of files and directories created (or destroyed) by self.
      def process(*argv)
        actions = []
        manifest(Manifest.new(actions), *argv)
        
        iterate(actions) do |action, args, block|
          send(action, *args, &block)
        end
      end
      
      # Overridden in subclasses to add actions to the input Manifest.
      # Any arguments passed to process will be passed to manifest
      # unchanged.
      def manifest(m, *argv)
        raise NotImplementedError
      end
      
      # Peforms each of the input actions in order, and collects the
      # results.  The process method returns these results.
      def iterate(actions)
        actions.collect {|action| yield(action) }
      end
      
      # Constructs a path relative to destination_root.
      def path(*paths)
        destination_root.path(*paths)
      end
      
      # Peforms a directory action (ex generate or destroy).  Must be
      # overridden by one of the action mixins (ex Generate or Destroy).
      def directory(target, options={})
        raise NotImplementedError
      end
    
      # Peforms a file action (ex generate or destroy).  Calls to file specify
      # input for a target by providing a block; the block recieves an IO and
      # pushes content to it.  Must be overridden by one of the action mixins
      # (ex Generate or Destroy).
      def file(target, options={}) # :yields: io
        raise NotImplementedError
      end
      
      # Makes (or destroys) the root and each of the targets, relative
      # to root.  Options are passed onto directory.
      def directories(root, targets, options={})
        results = [directory(root, options)]
        targets.each do |target|
          results << directory(File.join(root, target), options)
        end
        results
      end
      
      # Makes (or destroys) the target by templating the source using
      # the specified attributes.  Source is expanded relative to
      # template_root.  Options are passed onto file.
      def template(target, source, attributes={}, options={})
        template_path = template_root.path(source)
        templater = Templater.new(File.read(template_path), attributes)
        
        file(target, options) do |file| 
          file << templater.build(nil, template_path)
        end
      end
      
      # Yields each source file under template_root to the block, with
      # a target path of the source relative to template_root.
      def template_files
        targets = []
        template_root.glob('**/*').sort.each do |source|
          next unless File.file?(source)
          
          target = template_root.relative_path(source)
          yield(source, target)
          targets << target
        end
        targets
      end
      
      # Calls the block when specified by the action for self.
      def on(*actions, &block)
        if actions.include?(action)
          block.call
        else
          nil
        end
      end
      
      # Returns the action for self (ie :generate or :destroy)
      def action
        raise NotImplementedError
      end
      
      # Logs the action with the relative filepath from destination_root to path.
      def log_relative(action, path)
        relative_path = destination_root.relative_path(path)
        log(action, relative_path || path)
      end
      
      protected
      
      def default_destination_root
        Root.new
      end
      
      def default_template_root
        class_path = self.class.to_s.underscore
        
        template_dir = nil
        app.env.path(:templates).each do |dir|
          path = File.join(dir, class_path)
          if File.directory?(path)
            template_dir = path
            break
          end
        end
        
        Root.new(template_dir || "templates/#{class_path}")
      end
    end
  end
end