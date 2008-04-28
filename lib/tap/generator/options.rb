module Tap
  module Generator
    module Options # :nodoc:
      protected
      
      # Adapted from code in 'rails/rails_generator/options.rb'
      def add_general_options!(opt)
        opt.separator ''
        opt.separator 'General Options:'
        
        opt.on('-h', '--help', 'Show this help message and quit.') { |v| options[:help] = v }
        opt.on('-p', '--pretend', 'Run but do not make any changes.') { |v| options[:pretend] = v }
        opt.on('-f', '--force', 'Overwrite files that already exist.') { options[:collision] = :force }
        opt.on('-s', '--skip', 'Skip files that already exist.') { options[:collision] = :skip }
        opt.on('-q', '--quiet', 'Suppress normal output.') { |v| options[:quiet] = v }
        opt.on('-t', '--backtrace', 'Debugging: show backtrace on errors.') { |v| options[:backtrace] = v }
        opt.on('-c', '--svn', 'Modify files with subversion. (Note: svn must be in path)') do
          options[:svn] = `svn status`.inject({}) do |opt, e|
            opt[e.chomp[7..-1]] = true
            opt
          end
        end
      end
    end
  end
end
