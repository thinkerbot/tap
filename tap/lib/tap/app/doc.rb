require 'tap/signals'

module Tap
  class App
    class Doc < Signals::Signal
      def call(args)
        if path = template_path
          Templater.build_file(template_path, process(args))
        else
          desc = self.class.desc
          desc.resolve
          Templater.build(desc.comment, process(args), desc.document.source_file)
        end
      end
      
      def template_path
        obj.env.path(:man, "#{self.class.to_s.underscore}.erb") do |file|
          File.exists?(file)
        end
      end
      
      def process(args)
        {:app => obj}
      end
    end
  end
end