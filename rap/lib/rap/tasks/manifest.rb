require 'rap/tasks/gem_task'

module Rap
  module Tasks
    # ::task prints files for a manifest
    class Manifest < GemTask
      
      config :omit, %w{rdoc pkg test}, &c.list(&c.regexp)
      
      def process(*args)
        super
      
        # collect files from the gemspec, labeling 
        # with true or false corresponding to the
        # file existing or not
        files = spec.files.inject({}) do |files, file|
          files[File.expand_path(file)] = [File.exists?(file), file]
          files
        end

        # gather non-rdoc/pkg files for the project
        # and add to the files list if they are not
        # included already (marking by the absence
        # of a label)
        Dir.glob("**/*").each do |file|
          next if File.directory?(file) || omit.any? {|pattern| file =~ pattern }

          path = File.expand_path(file)
          files[path] = ["", file] unless files.has_key?(path)
        end

        # sort and output the results
        files.values.sort_by {|exists, file| file }.each do |entry| 
          puts "%-5s %s" % entry
        end
      end
    end
  end
end