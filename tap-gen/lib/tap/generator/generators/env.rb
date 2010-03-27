require 'tap/generator/base'

module Tap
  module Generator
    module Generators
      # :startdoc::generator generate a tapenv file
      class Env < Tap::Generator::Base
        
        config :pattern, '**/*.rb', &c.string   # the glob pattern under each path
        config :lib, 'lib', &c.string           # the lib dir
        config :pathfile, 'tap.yml', &c.string  # the pathfile
        config :register, true, &c.switch       # register resource paths
        config :load_paths, true, &c.switch     # set load paths
        config :set, true, &c.switch            # set constants
        config :gems, [], 
          :long => :gem, 
          &c.list                               # gems to add
        config :tapenv, 'tapenv', &c.string     # the tapenv file name
        config :use_organize, true,
          :long => :organize,
          &c.switch                             # organize results a bit
        
        def manifest(m, *paths)
          lines = []
          paths.each do |path|
            lines.concat Tap::Env.generate(options(path))
          end
          
          gem_options.each do |options|
            lines.concat Tap::Env.generate(options)
          end
          
          lines.uniq!
          
          if use_organize
            lines = organize(lines)
          end
          
          m.file(tapenv) do |io|
            lines.each {|line| io.puts line }
          end
        end
        
        def options(path)
          config.to_hash.merge(:dir => path)
        end
        
        def gem_options
          specs = []
          gems.each do |gem_name|
            gem_name =~ /\A(.*?)([\s<>=~].+)?\z/
            dependency = Gem::Dependency.new($1, $2)
            collect_specs(dependency, specs)
          end
          
          most_recent_specs = {}
          specs.sort_by do |spec|
            spec.version
          end.reverse_each do |spec|
            most_recent_specs[spec.name] ||= spec
          end
          
          most_recent_specs.values.collect do |spec|
            pathfile = File.join(spec.full_gem_path, 'tap.yml')
            map = Tap::Env::Path.load(pathfile)
            map.merge!('lib' => spec.require_paths)
            
            {
              :dir => spec.full_gem_path,
              :lib => 'lib',
              :map => map,
              :set => File.exists?(pathfile)
            }
          end
        end
        
        def organize(lines)
          sets, everything_else = lines.partition {|line| line.index('set ') == 0 }
          sets.collect! {|set| set.split(' ', 4) }
          
          cmax = sets.collect {|set| set[1].length }.max
          rmax = sets.collect {|set| set[2].length }.max
          format = "%s %-#{cmax}s %-#{rmax}s %s"
          sets.collect! {|set| format % set }
          
          lines = everything_else + sets
          lines.sort!
          lines
        end
        
        protected
        
        def collect_specs(dependency, specs) # :nodoc:
          Gem.source_index.search(dependency).each do |spec|
            unless specs.include?(spec)
              specs << spec
              spec.runtime_dependencies.each do |dep|
                collect_specs(dep, specs)
              end
            end
          end
        end
      end 
    end
  end
end
