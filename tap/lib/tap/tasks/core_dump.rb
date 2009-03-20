module Tap
  module Tasks
    # :startdoc::manifest dumps the application
    #
    # A dump task to print the application data to a file or IO.  Currently the
    # dump result is only useful for viewing results.  In the future the core
    # dump will be reloadable so a terminated app may restart execution.
    #
    # A core dump may be used in a terminal round to capture all the unhandled
    # results from previous rounds; if no filepath is specified, the results
    # are printed to stdout.
    #  
    #   % tap run -- [tasks] --+ core_dump FILEPATH
    #
    class CoreDump < Tap::FileTask
      
      config :date, true, &c.switch              # Include a date
      config :date_format, '%Y-%m-%d %H:%M:%S'   # The date format
      config :info, true, &c.switch              # Dump the app state information
      config :aggregator, true, &c.switch        # Dump aggregator results
      config :audit, true, &c.switch             # Include the audit trails with results
      
      def process(target=$stderr)
        open_io(target) do |io|
          dump_to(io)
        end
      end
    
      def dump_to(io)
        io.puts "# date: #{Time.now.strftime(date_format)}" if date
        io.puts "# info: #{app.info}" if info
        
        if aggregator
          trails = []
          results = {}
          app.aggregator.to_hash.each_pair do |src, _results|
            results["#{src} (#{src.object_id})"] = _results.collect {|_audit| _audit.value }
            _results.each {|_audit| trails << _audit.dump }
          end
      
          if audit
            io.puts "# audit:"
            trails.each {|trail| io.puts "# #{trail.gsub("\n", "\n# ")}"}
          end
                
          YAML::dump(results, io)
        end
      end
      
      
    end
  end
end