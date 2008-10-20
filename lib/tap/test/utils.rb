require 'tap/root'
require 'fileutils'
require 'tempfile'

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')
  end
  
  module Test
    module Utils
      module_function
      
      # Generates an array of [source, reference] pairs mapping source
      # files to reference files under the source and reference dirs,
      # respectively.  Only files under source dir matching the pattern
      # will be mapped.  Mappings are either (in this order):
      #
      # - the path under reference_dir contained in the source file
      # - a direct translation of the source file from the source to
      #   the reference dir, minus the extname
      #
      # Notes:
      # - Source files may contain comments but should otherwise
      #   consist only of indentation (which is stripped) and
      #   the reference path.
      # - If a mapped path cannot be found, dereference raises  
      #   a DereferenceError.
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
      # The 'two.txt.ref' file contains a reference path:
      #
      #  File.read('/root/input/two.txt.ref')    # => 'path/to/two.txt'
      #
      # Now:
      #
      #  reference_map('/root/input', '/root/ref')
      #  # => [
      #  # ['/root/input/dir.ref',     '/root/ref/dir'],
      #  # ['/root/input/one.txt.ref', '/root/ref/one.txt'],
      #  # ['/root/input/two.txt.ref', '/root/ref/path/to/two.txt']]
      #
      # And since no path matches 'ignored.txt':
      #
      #  reference_map('/root/input', '/root/ref', '**/*.txt')     
      #  # !> DereferenceError
      #
      def reference_map(source_dir, reference_dir, pattern='**/*.ref')
        Dir.glob(File.join(source_dir, pattern)).sort.collect do |source|
          # use the path specified in the source file
          relative_path = File.read(source).gsub(/#.*$/, "").strip
          
          # use the relative filepath of the source file to the
          # source dir (minus the extname) if no path is specified
          if relative_path.empty?
            relative_path = Tap::Root.relative_filepath(source_dir, source).chomp(File.extname(source))
          end
          
          reference = File.join(reference_dir, relative_path)
          
          # raise an error if no reference file is found
          unless File.exists?(reference)
            raise DereferenceError, "no reference found for: #{source}"
          end

          [source, reference]
        end
      end
      
      # Dereferences source files with reference files for the duration
      # of the block.  The mappings of source to reference files are
      # determined using reference_map; dereferenced files are at the
      # same location as the source files, but with the '.ref' extname
      # removed.
      #
      # Notes:
      # - The reference extname is implicitly specified in pattern;
      #   the final extname of the source file is removed during
      #   dereferencing regardless of what it is.
      #
      def dereference(source_dirs, reference_dir, pattern='**/*.ref', tempdir=Dir::tmpdir)
        mapped_paths = []
        begin
          [*source_dirs].each do |source_dir|
            reference_map(source_dir, reference_dir, pattern).each do |source, reference|
              
              # move the source file to a temporary location
              tempfile = Tempfile.new(File.basename(source), tempdir)
              tempfile.close
              FileUtils.mv(source, tempfile.path)
              
              # copy the reference to the target
              target = source.chomp(File.extname(source))
              FileUtils.cp_r(reference, target)
              
              mapped_paths << [target, source, tempfile]
            end
          end unless reference_dir == nil
          
          yield
          
        ensure
          mapped_paths.each do |target, source, tempfile|
            # remove the target and restore the original source file
            FileUtils.rm_r(target) if File.exists?(target)
            FileUtils.mv(tempfile.path, source)
          end
        end
      end
      
      # Uses a Tap::Support::Templater to template and replace the contents of path, 
      # for the duration of the block.  The attributes will be available in the
      # template context.
      def template(paths, attributes={}, tempdir=Dir::tmpdir)
        mapped_paths = []
        begin
          [*paths].each do |path|
            # move the source file to a temporary location
            tempfile = Tempfile.new(File.basename(path), tempdir)
            tempfile.close
            FileUtils.cp(path, tempfile.path)
              
            # template the source file
            content = File.read(path)
            File.open(path, "wb") do |file|
              file << Support::Templater.new(content, attributes).build
            end
            
            mapped_paths << [path, tempfile]
          end

          yield
          
        ensure
          mapped_paths.each do |path, tempfile|
            # restore the original source file
            FileUtils.rm(path) if File.exists?(path)
            FileUtils.mv(tempfile.path, path)
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
      def each_pair_with_index(a, b, error_msg=nil, &block) # :yields: entry_a, entry_b, index
        a = [a] unless a.kind_of?(Array)
        b = [b] unless b.kind_of?(Array)
        
        unless a.length == b.length
          raise ArgumentError, (error_msg || "The input arrays must have an equal number of entries.")
        end
        
        0.upto(a.length-1) do |index|
          yield(a[index], b[index], index)
        end
      end
      
      # Attempts to recursively remove the specified method directory and all 
      # files within it.  Raises an error if the removal does not succeed.
      def clear_dir(dir)
        # clear out the folder if it exists
        FileUtils.rm_r(dir) if File.exists?(dir)
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
      
      # Sets ARGV to the input argv for the duration of the block.
      def with_argv(argv=[])
        current_argv = ARGV.dup
        begin
          ARGV.clear
          ARGV.concat(argv)
          
          yield
          
        ensure
          ARGV.clear
          ARGV.concat(current_argv)
        end
      end
      
      def whitespace_escape(str)
        str.to_s.gsub(/\s/) do |match|
          case match
          when "\n" then "\\n\n"
          when "\t" then "\\t"
          when "\r" then "\\r"
          when "\f" then "\\f"
          else match
          end
        end
      end
      
      # Raised when no reference can be found for a reference path.
      class DereferenceError < StandardError
      end
    end
  end
end
