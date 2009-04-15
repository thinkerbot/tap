module Tap
  class App
    
    # Audit provides a way to track the values passed among Nodes.  Audits 
    # collectively build a {directed acyclic graph}[http://en.wikipedia.org/wiki/Directed_acyclic_graph] 
    # of task execution and have great utility in debugging and record keeping.
    #
    # Audits record a key, a current value, and the previous audit(s) in the
    # trail.  Keys are arbitrary identifiers of where the value comes from.
    # To illustrate, lets use symbols as keys.
    #
    #   # initialize a new audit
    #   _a = Audit.new(:one, 1)
    #   _a.key                              # => :one
    #   _a.value                            # => 1
    #
    #   # build a short trail
    #   _b = Audit.new(:two, 2, _a)
    #   _c = Audit.new(:three, 3, _b)
    #
    #   _a.sources                          # => []
    #   _b.sources                          # => [_a]
    #   _c.sources                          # => [_b]
    #
    # Audits allow you track back through the sources of each audit to build
    # a trail describing how a particular value was produced.
    #
    #   _c.trail                            # => [_a,_b,_c]
    #   _c.trail {|audit| audit.key }       # => [:one, :two, :three]
    #   _c.trail {|audit| audit.value }     # => [1,2,3]
    #
    # Any number of audits may share the same source, so forks are naturally
    # supported.
    #
    #   _d = Audit.new(:four, 4, _b)
    #   _d.trail                            # => [_a,_b,_d]
    #
    #   _e = Audit.new(:five, 5, _b)
    #   _e.trail                            # => [_a,_b,_e]
    #
    # Merges are supported by specifying more than one source.  Merges have 
    # the effect of nesting audit trails within an array:
    #
    #   _f = Audit.new(:six, 6)
    #   _g = Audit.new(:seven, 7, _f)
    #   _h = Audit.new(:eight, 8, [_c,_d,_g])
    #   _h.trail                            # => [[[_a,_b,_c], [_a,_b,_d], [_f,_g]], _h]
    #   
    # Nesting can get quite ugly after a couple merges so Audit provides a
    # scalable pretty-print dump that helps visualize the audit trail.
    #
    #   "\n" + _h.dump
    #   # => %q{
    #   # o-[one] 1
    #   # o-[two] 2
    #   # |
    #   # |-o-[three] 3
    #   # | |
    #   # `---o-[four] 4
    #   #   | |
    #   #   | | o-[six] 6
    #   #   | | o-[seven] 7
    #   #   | | |
    #   #   `-`-`-o-[eight] 8
    #   # }
    #
    # In practice, tasks are recorded as keys. Thus audit trails can be used
    # to access task configurations and other information that may be useful
    # when creating reports or making workflow decisions.  Note that by
    # convention Audits and non-Audit methods that return Audits are
    # prefixed with an underscore.
    #
    #--
    # Note Audit could easily be expanded to track sinks as well as sources.
    # In initialize:
    #
    #   @sinks = []
    #   sources.each do |source|
    #     source.sinks << self
    #   end
    # 
    # The downside is that this may not circumvent cleanly if you want light
    # or no auditing.  It also adds additonal references which will prevent
    # garbage collection.  On the plus side, sinks will make it easier to
    # truly use Audits as a DAG
    class Audit
      class << self
        def call(node, inputs)
          if node.respond_to?(:_call)
            return _call(node, inputs)
          end
          
          previous = []
          inputs.collect! do |input| 
            if input.kind_of?(Audit) 
              previous << input
              input.value
            else
              previous << new(nil, input)
              input
            end
          end

          # make an audited call if possible
          result = node.call(*inputs)
          new(node, result, previous)
        end
        
        def _call(node, inputs)
          inputs.collect! do |input| 
            if input.kind_of?(Audit) 
              input
            else
              new(nil, input)
            end
          end
          
          result = node._call(*inputs)
          new(node, result, inputs)
        end
        
        # Produces a pretty-print dump of the specified audits to target. 
        # A block may be provided to format the trailer of each line.
        def dump(audits, target=$stdout) # :yields: audit
          return dump(audits, target) do |audit| 
            "o-[#{audit.key}] #{audit.value.inspect}"
          end unless block_given?
          
          # arrayify audits
          audits = [*audits]#.flatten
          
          # the order of audits
          order = []
          
          # (audit, sinks) hash preventing double iteration over 
          # audits, and identifying sinks for a particular audit
          sinks = {}
          
          # iterate over all audits, collecting in order
          audits.each do |audit|
            traverse(audit, order, sinks)
          end
          
          # visit each audit, collecting audits into indent groups
          groups = []
          current = nil
          order.each do |audit|
            sources = audit.sources
            unless sources.length == 1 && sinks[sources[0]].length <= 1
              current = []
              groups << current
            end
            
            current << audit
          end
          
          # identify nodes at which a fork occurs... these are audits
          # that have more than one sink, and they cause a fork-style
          # leader to be printed
          forks = {}
          sinks.each_pair do |audit, audit_sinks|
            n = audit_sinks.length
            forks[audit] = [0, n] if n > 1
          end
          
          # setup print
          index = 0
          leader = ""
          
          # print each group
          groups.each do |group|
            sources = group[0].sources
            complete = audits.include?(group[-1])
            
            case 
            when sources.length > 1
              # print a merge
              # `-`-`-o-[merge]
              
              leader =~ /^(.*)((\| *){#{sources.length}})$/
              leader = "#{$1}#{' ' * $2.length} "
              target << "#{$1}#{$2.gsub('|', '`').gsub(' ', '-')}-#{yield(group.shift)}\n"
              
            when fork = forks[sources[0]]
              # print a fork
              # |-o-[a]
              # |
              # `---o-[b]
              
              n = fork[0] += 1
              base = leader[0, leader.length - (2 * n - 1)]
              target << "#{base}#{fork[0] == fork[1] ? '`-' : '|-'}#{'--' * (n-1)}#{yield(group.shift)}\n"
              leader  = "#{base}#{fork[0] == fork[1] ? '  ' : '| '}#{'| ' * (n-1)}"
              
            when index > 0
              # simply get ready to print the next series of audits
              # o-[a]
              # o-[b]
              
              leader = "#{leader} "
              leader = "" if leader.strip.empty?
            end
            
            # print the next series of audits
            group.each do |audit|
              target << "#{leader}#{yield(audit)}\n"
            end
            
            # add a continuation line, if necessary
            unless group == groups.last
              if complete
                leader = "#{leader} "
              else
                leader = "#{leader}|"
              end
              target << "#{leader}\n"
            end
            
            index += 1
          end
          
          target
        end
        
        protected
        
        # helper to determine the order and sinks for a node
        def traverse(node, order=[], sinks={}) # :nodoc:
          return if sinks.has_key?(node)
          
          node.sources.each do |source|
            traverse(source, order, sinks)
            (sinks[source] ||= []) << node
          end
          
          order << node
        end
      end
      
      # A key for self (typically the task producing value, or
      # nil if the value has an unknown origin)
      attr_reader :key
      
      # The current value
      attr_reader :value
      
      # Initializes a new Audit.  Sources may be an array, a single value
      # (which is turned into an array), or nil (indicating no sources).
      #
      #   _a = Audit.new(nil, nil, nil)
      #   _a.sources                        # => []
      #
      #   _b = Audit.new(nil, nil, _a)
      #   _b.sources                        # => [_a]
      #
      #   _c = Audit.new(nil, nil, [_a,_b])
      #   _c.sources                        # => [_a,_b]
      #
      def initialize(key=nil, value=nil, sources=nil)
        @key = key
        @value = value
        @source = singularize(sources)
      end
      
      # An array of source audits for self.  Sources may be empty.
      def sources
        arrayify(@source)
      end
      
      # Produces a fork of self for each item in value, using the index of
      # the item as a key.  Splat is useful for developing each item of an
      # array value along different paths.
      #
      #   _a = Audit.new(nil, [:x, :y, :z])
      #   _b,_c,_d = _a.splat
      #
      #   _b.key                            # => 0
      #   _b.value                          # => :x
      #
      #   _c.key                            # => 1
      #   _c.value                          # => :y
      #
      #   _d.key                            # => 2
      #   _d.value                          # => :z
      #   _d.trail                          # => [_a,_d]
      # 
      # If value does not respond to 'each', an array with self as the only
      # member will be returned.  This ensures that the result of splat
      # is an array of audits ready for further development.
      # 
      #   _a = Audit.new(nil, :value)
      #   _a.splat                          # => [_a]
      #
      def splat
        return [self] unless value.respond_to?(:each)
        
        collection = []
        index = 0
        value.each do |obj|
          collection << Audit.new(index, obj, self)
          index += 1
        end
        collection
      end
      
      def each
        splat.each do |obj|
          yield(obj)
        end
      end
      
      def to_ary
        splat
      end
      
      # Recursively collects an audit trail leading to self.  Single sources
      # are collected into the trail directly, while multiple sources are
      # collected into arrays.
      #
      #   _a = Audit.new(:one, 1)
      #   _b = Audit.new(:two, 2, _a)
      #   _b.trail                          # => [_a,_b]
      #
      #   _a = Audit.new(:one, 1)
      #   _b = Audit.new(:two, 2)
      #   _c = Audit.new(:three, 3, [_a, _b])
      #   _c.trail                          # => [[[_a],[_b]],_c]
      #
      # A block may be provided to collect a specific audit attribute
      # instead of the audit itself.
      #
      #   _c.trail {|audit| audit.value }   # => [[[1],[2]],3]
      #
      def trail(trail=[], &block)
        trail.unshift(block_given? ? block.call(self) : self)
        
        case @source
        when Audit
          @source.trail(trail, &block)
        when Array
          trail.unshift @source.collect {|audit| audit.trail(&block) }
        end
        
        trail
      end
      
      # A kind of pretty-print for Audits.
      def dump(&block)
        Audit.dump(self, "", &block)
      end
      
      private
      
      # helper to optimize storage of nodes
      def singularize(obj) # :nodoc:
        return obj unless obj.kind_of?(Array)
        
        case obj.length
        when 0 then nil
        when 1 then obj[0]
        else obj
        end
      end
      
      # helper to optimize storage of nodes
      def arrayify(obj) # :nodoc:
        case obj
        when nil then []
        when Array then obj
        else [obj]
        end
      end
    end
  end
end