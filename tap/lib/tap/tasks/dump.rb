module Tap
  module Tasks
    # :startdoc::manifest the default dump task
    #
    # A dump task to print aggregated application results to a file or IO.  
    # The results are printed as YAML, allowing dumped results to be 
    # reloaded and used as inputs to other tasks.
    #
    # Often dump is used as the final task in a round of tasks; if no filepath 
    # is specified, the results are printed to stdout.
    #  
    #   % tap run -- [tasks] --+ dump FILEPATH
    #
    # See Load for more details.
    class Dump < Tap::FileTask
      
      config :date_format, '%Y-%m-%d %H:%M:%S'   # the date format
      config :audit, true, &c.switch             # include the audit trails
      config :date, true, &c.switch              # include a date
      config :filter, nil, &c.regexp_or_nil      # only dump matching objects
      
      # Calls dump_to with the target.  If the target is not an
      # IO, process assumes the target is a filepath.  In that
      # case, the file is prepared and the results dumped to it.
      def process(target=$stdout)
        case target
        when IO then dump_to(target)
        else
          log_basename(:dump, target)
          prepare(target)
          File.open(target, "wb") {|file| dump_to(file) }
        end
      end
    
      # Dumps the current results in app.aggregator to the io.
      # The dump will include the result audits and a date,
      # as specified in config.
      def dump_to(io)
        trails = []
        results = {}
        app.aggregator.to_hash.each_pair do |src, _results|
          next if filter && src.to_s !~ filter
          
          results["#{src} (#{src.object_id})"] = _results.collect {|_audit| _audit.value }
          _results.each {|_audit| trails << _audit.dump }
        end
      
        if audit
          io.puts "# audit:"
          trails.each {|trail| io.puts "# #{trail.gsub("\n", "\n# ")}"}
        end
        
        if date
          io.puts "# date: #{Time.now.strftime(date_format)}"
        end
        
        YAML::dump(results, io)
      end
    end
  end
end