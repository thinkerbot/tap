require 'tap/joins'
require 'tap/schema/node'
autoload(:Shellwords, 'shellwords')

module Tap
  class Schema
    autoload(:Parser, 'tap/schema/parser')
    
    class << self
      def parse(argv=ARGV)
        Parser.new(argv).schema
      end

      def load(str)
        argh = YAML.load(str) || {}
        argh = argh.inject(
          :nodes => [],
          :joins => []
        ) do |hash, (key, value)|
          hash[key.to_sym || key] = value
          hash
        end
        
        nodes = argh[:nodes].collect {|node| Node.new(node) }
        schema = new(nodes)
        
        # add joins
        argh[:joins].each do |obj|
          inputs, outputs, metadata = if obj.kind_of?(Hash)  
            [obj.delete(:inputs), obj.delete(:outputs), obj]
          else 
            obj
          end
          
          join = Join.new([], [], metadata)
          
          inputs.each do |index|
            schema[index].output = join
          end
          
          outputs.each do |index|
            schema[index].input = join
          end
        end
        
        schema
      end
      
      # Loads a schema from the specified path.  Raises an error if no such
      # file existts.
      def load_file(path)
        load(File.read(path))
      end
    end
    
    # An array of the nodes in self.  Nodes may contain nils.
    attr_reader :nodes
    
    def initialize(nodes=[])
      @nodes = nodes
    end
    
    # Retrieves the node at index, or instantiates a new Node if one does
    # not already exists.
    def [](index)
      nodes[index] ||= Node.new
    end
    
    # Returns the index of the node in nodes.
    def index(node)
      nodes.index(node)
    end
    
    # Returns an array of the metadata for each nodes.
    def metadata
      nodes.collect do |node|
        node == nil ? nil : node.metadata
      end
    end
    
    # Returns the indicies of each node, or nil if nodes is nil.
    def indicies(nodes)
      nodes ? nodes.collect {|node| index(node) } : nodes
    end
    
    # Returns an array of joins among nodes in self.
    def joins
      joins = []
      
      nodes.each do |node|
        next unless node
        if join = node.output
          joins << join
        end
      end
      
      nodes.each do |node|
        next unless node
        if join = node.input
          joins << join
        end
      end
      
      joins.uniq
    end
    
    # Sets a join between the nodes at the input and output indicies.
    # Returns the new join.
    def set_join(inputs, outputs, metadata={})
      join = Join.new [],[], metadata
      
      inputs.each {|index| self[index].output = join }
      outputs.each {|index| self[index].input = join }
      
      join
    end
    
    # Removes all nil nodes, nodes with empty argvs, and orphaned joins.
    # Returns self.
    def cleanup
      # remove nil and empty nodes
      nodes.delete_if do |node|
        node == nil || node.empty?
      end
      
      # cleanup joins
      joins.each do |join|
        
        # remove missing output nodes
        join.outputs.delete_if {|node| !nodes.include?(node) }
        
        # remove missing input nodes
        join.inputs.delete_if {|node| !nodes.include?(node) }
        
        # detach if orphanded
        join.detach! if join.orphan?
      end
      
      self
    end
    
    # Creates an hash dump of self.
    def to_hash
      cleanup
      
      hash = {}
      hash[:nodes] = nodes.collect do |node|
        node.metadata
      end
      hash[:joins] = joins.collect do |join|
        metadata = join.metadata
        inputs = indicies(join.inputs)
        outputs = indicies(join.outputs)
        
        if metadata.kind_of?(Hash)
          metadata.merge(:inputs => inputs, :outputs => outputs)
        else
          [inputs, outputs, metadata]
        end
      end
      
      # hash[:middleware] = middleware.collect do |middleware| 
      #   middleware.metadata
      # end
      
      hash.delete_if {|key, value| value.empty? }
      hash
    end
    
    # Converts self to a hash and serializes it to YAML.
    def dump
      YAML.dump(to_hash)
    end
  end
end