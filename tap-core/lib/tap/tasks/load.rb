module Tap
  module Tasks
    # :startdoc::manifest the default load task
    #
    # Load YAML-formatted data, as may be produced using Tap::Dump,
    # and makes this data available for other tasks.  Load is often
    # used as a gateway task to other tasks.
    #
    #   % tap run -- load FILEPATH --: [task]
    #
    # Load can select items from Hash or Array objects using one or
    # more keys when only a subset is desired.  By default items are
    # selected using [].  For more flexible selection, use match.
    # 
    # Match converts each of the keys to a Regexp.  For hashes, all
    # values with a matching key will be selected.  For arrays, any
    # item matching a regexp will be selected.
    #
    # Use the flags to flatten, compact, sort (etc) results before
    # passing them on to the next task.
    class Load < Tap::Task
      
      config :match, false, :short => :m, &c.switch      # match keys
      config :flatten, false, :short => :f, &c.switch    # flatten results
      config :compact, false, :short => :c, &c.switch    # compact results
      config :unique, false, :short => :u, &c.switch     # uniq results
      config :sort, false, :short => :s, &c.switch       # sort results
      #config :preview, false, :short => :p, &c.switch    # logs result
      
      # Loads the input as YAML and selects objects using keys.  Input may
      # be an IO, StringIO, or a filepath.  If keys are empty, the loaded
      # object is returned directly.
      #
      # ==== Key Selection
      # Keys select items from the loaded object using [] (ie obj[key]).
      # If match==true, the behavior is different; each string key is
      # converted into a Regexp and then arrays select items that match
      # key:
      #
      #   results = []
      #   array.each {|i| results << i if i =~ key}
      #
      # While hashes select values where the key matches key:
      #
      #   results = []
      #   hash.each_pair {|k,v| results << v if k =~ key}
      #
      # Other objects raise an error when match is true.  
      #
      # ==== Post Processing
      # After loading/key selection, the results may be processed (in this
      # order) using flatten, compact, unique, and sort, each performing as
      # you would expect.  
      # 
      def process(input, *keys)
        
        # load the input
        obj = case input
        when StringIO, IO
          YAML.load(input.read)
        else
          log :load, input
          YAML.load_file(input)
        end
        
        # select results by key
        results = case
        when keys.empty? then obj
        when match 
          regexps = keys.collect {|key| Regexp.new(key.to_s) }
          select_matching(obj, regexps)
        else 
          keys.collect do |key| 
            index = key.kind_of?(String) ? YAML.load(key) : key
            obj[index]
          end
        end
        
        # post-process results
        results = results.flatten if flatten
        results = results.compact if compact
        results = results.uniq if unique
        results = results.sort if sort
        
        #if preview
          # should be a log or something
          #puts results.inspect
        #end
        
        results
      end
      
      protected
      
      # selects items from obj which match one of the regexps.
      def select_matching(obj, regexps) # :nodoc:
        case obj
        when Array
          obj.select {|item| regexps.any? {|r| item =~ r} }
        when Hash
          results = []
          obj.each_pair do |key, value|
            results << value if regexps.any? {|r| key =~ r}
          end
          results
        else
          raise ArgumentError, "cannot match keys from a #{obj.class}"
        end
      end
    end 
  end
end
