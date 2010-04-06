require 'tap/task'

module Tap
  class Workflow < App::Api
    class << self
      protected
      
      # Defines a task subclass with the specified configurations and process
      # block. During initialization the subclass is instantiated and made
      # accessible through the name method.  
      #
      # Defined tasks may be configured during through config, or directly
      # through the instance; in effect you get tasks with nested configs which
      # can greatly facilitate workflows.
      #
      #   class AddALetter < Tap::Task
      #     config :letter, 'a'
      #     def process(input); input << letter; end
      #   end
      #
      #   class AlphabetSoup < Tap::Task
      #     define :a, AddALetter, {:letter => 'a'}
      #     define :b, AddALetter, {:letter => 'b'}
      #     define :c, AddALetter, {:letter => 'c'}
      #
      #     def initialize(*args)
      #       super
      #       a.sequence(b, c)
      #     end
      # 
      #     def process
      #       a.execute("")
      #     end
      #   end
      #
      #   AlphabetSoup.new.process            # => 'abc'
      #
      #   i = AlphabetSoup.new(:a => {:letter => 'x'}, :b => {:letter => 'y'}, :c => {:letter => 'z'})
      #   i.process                           # => 'xyz'
      #
      #   i.config[:a] = {:letter => 'p'}
      #   i.config[:b][:letter] = 'q'
      #   i.c.letter = 'r'
      #   i.process                           # => 'pqr'
      #
      # ==== Usage
      #
      # Define is basically the equivalent of:
      #
      #   class Sample < Tap::Task
      #     Name = baseclass.subclass(config, &block)
      #     
      #     # accesses an instance of Name
      #     attr_reader :name
      #
      #     # register name as a config, but with a
      #     # non-standard reader and writer
      #     config :name, {}, {:reader => :name_config, :writer => :name_config=}.merge(options)
      #
      #     # reader for name.config
      #     def name_config; ...; end
      #
      #     # reconfigures name with input
      #     def name_config=(input); ...; end
      #
      #     def initialize(*args)
      #       super
      #       @name = Name.new(config[:name])
      #     end
      #   end
      #
      # Note the following:
      # * define will set a constant like name.camelize
      # * the block defines the process method in the subclass
      # * three methods are created by define: name, name_config, name_config=
      #
      def define(name, baseclass=Tap::Task, configs={}, options={}, &block)
        # define the subclass
        subclass = Class.new(baseclass)
        configs.each_pair do |key, value|
          subclass.send(:config, key, value)
        end

        if block_given?
          # prevent lazydoc registration of the process method
          subclass.registered_methods.delete(:process)
          subclass.send(:define_method, :process, &block)
        end

        # register documentation
        # TODO: register subclass in documentation
        options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer, 1)

        # add the configuration
        nest(name, subclass, {:const_name => name.to_s.camelize}.merge!(options))
      end
    end
    
    def call(input)
      nodes = process
      
      unless nodes.kind_of?(Array)
        nodes = [nodes]
      end
      
      nodes.collect do |node|
        app.execute(node, input)
      end
    end
  end
end