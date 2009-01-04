require 'tap/support/templater'
require 'stringio'

module Tap
  module Test
    
    # A module of functions to help test generators.
    module GeneratorTest
      
      # Builds and returns the content of a file by calling block with a 
      # StringIO. Returns nil if block is nil.
      def build_file(block)
        return nil if block == nil
        io = StringIO.new("")
        block.call(io)
        io.string
      end
      
      # Builds a template using the template, and the input attributes.  
      # Templates are built using a Tap::Support::Templater.
      def build_template(template, attributes)
        Tap::Support::Templater.new(template, attributes).build
      end
      
      # Returns the path of path, relative to root.
      def relative_path(root, path)
        Tap::Root.relative_filepath(root, path)
      end
      
      # A helper to assert that the actions recorded from a manifest are as
      # expected.  assert_actions simplifies the expected input by recollecting
      # the actual paths relative to root.  Any files or templates are built
      # and passed to the block.
      #
      # Say a generator creates actual actions like this:
      #
      #   template_path = "template.erb"
      #   File.open(template_path, "w") {|file| file << "<%= key %> was templated"}
      #
      #   actions = []
      #   m = Manifest.new(actions)
      #   m.directory '/path/to/dir'
      #   m.file('/path/to/dir/file.txt') {|io| io << "content"}
      #   m.template('/path/to/dir/template.txt', template_path, :key => 'value')
      #
      # These assertions will pass:
      #
      #   builds = {}
      #   assert_actions [
      #     [:directory, 'dir'],
      #     [:file, 'dir/file.txt'],
      #     [:template, 'dir/template.txt']
      #   ], actions, '/path/to' do |file, content|
      #     builds[file] = content
      #   end
      #
      #   assert_equal "content", builds['dir/file.txt']
      #   assert_equal "value was templated", builds['dir/template.txt']
      #
      # assert_actions is specifically designed for testing the standard
      # generator actions and may not work for custom actions.
      def assert_actions(expected, actual, root=Dir.pwd) # :yields: file, content
        assert_equal expected.length, actual.length, "unequal number of actions"

        index = 0
        actual.each do |action, args, block|
          expect_action, expect_path = expected[index]

          assert_equal expect_action, action, "unequal action at index: #{index}"
          assert_equal expect_path, relative_path(root, args[0]), "unequal path at index: #{index}"

          case action
          when :file
            yield(expect_path, build_file(block)) 
          when :template
            yield(expect_path, build_template(File.read(args[1]), args[2]))
          end if block_given?

          index += 1
        end
      end
    end
  end
end