require 'tap'
require 'tap/generator/manifest'
require 'tap/generator/arguments'

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
    # a mixin with the appropriate funtion (ie Generate or Destory) is 
    # overlaid to figure out how to roll those actions forward or backwards.
    #
    # Unlike typical tasks, generators must be named like '<Name>Generator' and
    # are identified using the ::generator flag rather than ::manifest.  These
    # requirements make generators available to the generate/destroy commands
    # and not run.
    #
    # Typically, generators live in a directory structure like this:
    #
    #   sample
    #   |- sample_generator.rb
    #   `- templates
    #       `- template_file.erb
    #
    # And take the form:
    #
    #   [sample/sample_generator.rb]
    #   require 'tap/generator/base'
    #
    #   # SampleGenerator::generator generates a directory, and two files
    #   #
    #   # An extended description of the
    #   # generator goes here...
    #   #
    #   class SampleGenerator < Tap::Generator::Base
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
    #       # template a file using config
    #       m.template('path/to/result.txt', 'template_file.erb', config.to_hash)
    #     end
    #   end
    #
    # As with any task, generators can have configurations and take arguments
    # specified by manifest (minus the 'm' argument which is standard).  
    # Creating directories and files is straightforward, as above.  Template
    # generates a target file using the source file in the templates' directory;
    # any attributes specified by the last argument will be available in the erb
    # template.
    # :startdoc:::+
    class Base < Tap::Task
      lazy_attr :manifest, 'generator'
      lazy_attr :args, :manifest
      lazy_register :manifest, Arguments
      
      config :destination_root, Dir.pwd       # The destination root directory
      config :pretend, false, &c.flag         # Run but rollback any changes.
      config :force, false, &c.flag           # Overwrite files that already exist.
      config :skip, false, &c.flag            # Skip files that already exist.
      
      # The generator-specific templates directory.  By default:
      # 'path/to/name/templates' for 'path/to/name/name_generator.rb'
      attr_accessor :template_dir
      
      # The IO used to pull prompt inputs (default: $stdin)
      attr_accessor :prompt_in
      
      # The IO used to prompt users for input (default: $stdout)
      attr_accessor :prompt_out
      
      def initialize(*args)
        super
        @prompt_in = $stdin
        @prompt_out = $stdout
        @template_dir = File.expand_path("templates/#{self.class.default_name}")
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
        File.expand_path(File.join(*paths), destination_root)
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
        directory(root, options)
        targets.each do |target|
          directory(File.join(root, target), options)
        end
      end
      
      # Makes (or destroys) the target by templating the source using
      # the specified attributes.  Source is expanded relative to
      # template_dir.  Options are passed onto file.
      def template(target, source, attributes={}, options={})
        template_path = File.expand_path(source, template_dir)
        templater = Support::Templater.new(File.read(template_path), attributes)
        
        file(target, options) do |file| 
          file << templater.build
        end
      end
      
      # Yields each source file under template_dir to the block, with
      # a target path of the source relative to template_dir.
      def template_files
        Dir.glob(template_dir + "/**/*").sort.each do |source|
          next unless File.file?(source)
          
          target = Tap::Root::Utils.relative_path(template_dir, source)
          yield(source, target)
        end
      end
      
      # Logs the action with the relative filepath from Dir.pwd to path.
      def log_relative(action, path)
        log(action, Tap::Root::Utils.relative_path(Dir.pwd, path))
      end
    end
  end
end