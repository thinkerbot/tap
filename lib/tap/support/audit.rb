module Tap
  module Support
    
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
        
        # Produces a pretty-print dump of a series of nodes to target.
        def dump(audits, target=$stdout)
          return dump(audits, target) do |audit| 
            "o-[#{audit.key}] #{audit.value.inspect}"
          end unless block_given?
          
          # arrayify audits
          audits = [audits].flatten
          
          # the order of audits
          order = []
          
          # (audit, count) used to prevent double
          # iteration over audits.
          sinks = {}
          
          # iterate over all audits, collecting in order
          audits.each do |audit|
            traverse(audit, order, sinks)
          end
          
          # now visit each audit, collecting audits into groups
          groups = []
          group = nil
          order.each do |audit|
            sources = audit.sources
            unless sources.length == 1 && sinks[sources[0]].length <= 1
              group = []
              groups << group
            end
            
            group << audit
          end
          
          # setup print
          forks = {}
          sinks.each_pair do |audit, sinks|
            n = sinks.length
            forks[audit] = [0, n] if n > 1
          end

          index = 0
          leader = ""
          
          # print each group
          groups.each do |group|
            sources = group[0].sources
            complete = audits.include?(group[-1])
            
            case 
            when sources.length > 1
              leader =~ /^(.*)((\| *){#{sources.length}})$/
              leader = "#{$1}#{' ' * $2.length} "
              target << "#{$1}#{$2.gsub('|', '`').gsub(' ', '-')}-#{yield(group.shift)}\n"
              
            when fork = forks[sources[0]]
              n = fork[0] += 1
              base = leader[0, leader.length - (2 * n - 1)]
              target << "#{base}#{fork[0] == fork[1] ? '`-' : '|-'}#{'--' * (n-1)}#{yield(group.shift)}\n"
              leader  = "#{base}#{fork[0] == fork[1] ? '  ' : '| '}#{'| ' * (n-1)}"
              
            when index > 0
              leader = "#{leader} "
              leader = "" if leader.strip.empty?
            end
            
            group.each do |audit|
              target << "#{leader}#{yield(audit)}\n"
            end
            
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
        
        # helper to determine the order and sinks for a node.
        # used in dump
        def traverse(node, order=[], sinks={}) # :nodoc:
          return if sinks.has_key?(node)
          
          node.sources.each do |source|
            traverse(source, order, sinks)
            (sinks[source] ||= []) << node
          end
          
          order << node
        end
      end
      
      # A key for self
      attr_reader :key
      
      # The current value
      attr_reader :value
      
      # An arbitrary object used to identify when no value has been
      # provided to Audit.new.  (nil cannot be used since nil is a
      # valid value)
      AUDIT_NIL = Object.new
      
      def initialize(key=nil, value=AUDIT_NIL, sources=nil)
        @key = key
        @value = value
        @source = singularize(sources)
      end
      
      # An array of source audits for self.
      def sources
        arrayify(@source)
      end
      
      def _iterate
        return [self] unless value.respond_to?(:each)
        
        collection = []
        index = 0
        value.each do |obj|
          collection << Audit.new(index, obj, self)
          index += 1
        end
        collection
      end
      
      def _source_trails(trails=[], &block)
        case @source
        when Audit
          @source._source_trails(trails, &block)
        when Array
          @source.collect do |audit| 
            trails.concat audit._source_trails(&block)
          end
        when nil
          trails << []
        end
        
        trails.each do |trail|
          trail.push(block_given? ? block.call(self) : self)
        end
        trails
      end
      
      def _sink_trail(trail=[], &block)
        trail.unshift(block_given? ? block.call(self) : self)
        
        case @source
        when Audit
          @source._sink_trail(trail, &block)
        when Array
          trail.unshift @source.collect {|audit| audit._sink_trail(&block) }
        end
        
        trail
      end
      
      # A kind of pretty-print for Audits.
      def _to_s(&block)
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