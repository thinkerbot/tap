module Tap
  # ::manifest
  # A primitive dump task (still in development) to print  
  # application results to a file or IO.  The results are
  # printed in a tap-readable format allowing the use of
  # dumped results as inputs to other tasks.
  #
  # Usually dump is used as the final task in a round of
  # tasks executed through 'tap run'.
  # === Usage
  #   % tap run -- [your tasks] --+ dump filepath
  #
  # If no filepath is specified, the results are printed
  # to stdout.
  #
  class Dump < Tap::FileTask
    
    config :datetime_format, '%Y-%m-%d %H:%M:%S'
    config :print_audit, true
    config :print_date, true
    
    #config :overwrite
    
    def process(target=$stdout)
      case target
      when IO then dump_to(target)
      else
        log_basename(:dump, target)
        prepare(target)
        File.open(target, "wb") {|file| dump_to(file) }
      end
    end
    
    def dump_to(io)
      trails = []
      results = {}
      app.aggregator.to_hash.each_pair do |src, _results|
        name = src.respond_to?(:name) ? src.name : ''

        results["#{name} (#{src.object_id})"] = _results.collect {|_audit| _audit._current }
        _results.each {|_audit| trails << _audit._to_s }
      end
      
      if print_audit
        io.puts "# audit:"
        trails.each {|trail| io.puts "# #{trail.gsub("\n", "\n# ")}"}
      end
        
      if print_date
        io.puts "# date: #{Time.now.strftime(datetime_format)}"
      end
        
      YAML::dump(results, io)
    end
    
  end
end