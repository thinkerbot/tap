require 'tap/root'
require 'fileutils'

module Tap
  module Test
    module Utils
      module_function
      
      # Generates an array of [source, reference] pairs mapping source
      # files to reference files under the source_dir and reference_dir,
      # respectively.  Only files under source dir with the reference_extname
      # will be mapped; mappings are either:
      #
      # - a direct translation from source_dir to reference_dir, minus
      #   the extname
      # - a path under reference_dir with a matching basename, minus
      #   the extname, so long as the matched path is unique
      #
      # If a mapped path cannot be found, dereference raises an ArgumentError.
      #
      # === example
      #
      #   root
      #   |- input
      #   |   |- dir.ref
      #   |   |- ignored.txt
      #   |   |- one.txt.ref
      #   |   `- two.txt.ref
      #   `- ref
      #       |- dir
      #       |- one.txt
      #       `- path
      #           `- to
      #               `- two.txt
      #
      #  reference_map('/root/input', '/root/ref')
      #  # => [
      #  # ['/root/input/dir.ref',     '/root/ref/dir'],
      #  # ['/root/input/one.txt.ref', '/root/ref/one.txt'],
      #  # ['/root/input/two.txt.ref', '/root/ref/path/to/two.txt']]
      #
      #  reference_map(:input, :ref, ".txt")  # !> ArgumentError
      #
      def reference_map(source_dir, reference_dir, reference_extname='.ref')
        Dir.glob(File.join(source_dir, "**/*#{reference_extname}")).collect do |path|
          relative_path = Tap::Root.relative_filepath(source_dir, path).chomp(reference_extname)
          reference_path = File.join(reference_dir, relative_path)

          unless File.exists?(reference_path)
            matching_paths = Dir.glob(File.join(reference_dir, "**/#{File.basename(relative_path)}"))

            reference_path = case matching_paths.length
            when 0 then raise ArgumentError, "no reference found for: #{path}"
            when 1 then matching_paths[0]
            else raise ArgumentError, "multiple references found for: #{path} [#{matching_paths.join(', ')}]"
            end
          end

          [path, reference_path]
        end
      end
      
      def dereference(source_dirs, reference_dir, extname='.ref')
        mapped_paths = []
        begin
          [*source_dirs].each do |source_dir|
            reference_map(source_dir, reference_dir, extname).each do |path, source|
              FileUtils.rm_r(path)
              target = path.chomp(extname)
              FileUtils.cp_r(source, target)
              mapped_paths << target
            end
          end unless reference_dir == nil
          
          yield
          
        ensure
          mapped_paths.each do |path|
            FileUtils.rm_r(path) if File.exists?(path)
            FileUtils.touch(path + extname)
          end
        end
      end
      
      # Yields to the input block for each pair of entries in the input 
      # arrays.  An error is raised if the input arrays do not have equal 
      # numbers of entries.
      def each_pair(a, b, &block) # :yields: entry_a, entry_b,
        each_pair_with_index(a,b) do |entry_a, entry_b, index|
          yield(entry_a, entry_b)
        end
      end

      # Same as each_pair but yields the index of the entries as well.
      def each_pair_with_index(a, b, &block) # :yields: entry_a, entry_b, index
        a = [a] unless a.kind_of?(Array)
        b = [b] unless b.kind_of?(Array)

        raise ArgumentError, "The input arrays must have an equal number of entries." unless a.length == b.length
        0.upto(a.length-1) do |index|
          yield(a[index], b[index], index)
        end
      end
      
      # Attempts to remove the specified directory.  The root 
      # will not be removed if the directory does not exist, or
      # is not empty.  
      def try_remove_dir(dir)
        # Remove the directory if possible
        begin
          FileUtils.rmdir(dir) if File.exists?(dir) && Dir.glob(File.join(dir, "*")).empty?
        rescue
          # rescue cases where there is a hidden file, for example .svn
        end
      end
    end
  end
end