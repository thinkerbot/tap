module Tap
  class App
    class Doc < Signals::Signal
      alias app obj
      
      attr_reader :env
      
      def initialize(app)
        super(app)
        @env = app.env
      end
      
      def call(argv)
        unless env.kind_of?(Tap::Env)
          raise "doc pages are only available for Tap::Env environments"
        end
        
        args = convert_to_array(argv, ['const_name', 'page'])
        process(*args)
      end
      
      def process(const_name=nil, page=nil)
        constant = const_name ? app.resolve(const_name) : nil
        
        case
        when constant && page
          render(constant, page)
        when constant
          pages(constant)
        else
          summarize
        end
      end
      
      def summarize
        "constants:\n#{env.constants.summarize}"
      end
      
      def pages(constant)
        pages = []
        env.module_path(:doc, superclasses(constant)) do |dir|
          next unless File.directory?(dir)
          
          Dir.chdir(dir) do
            Dir.glob("*.*").each do |page|
              pages << "  #{page.chomp(File.extname(page))}"
            end
          end
        end
        
        if pages.empty?
          "no pages available (#{constant})"
        else
          "pages: (#{constant})\n#{pages.join("\n")}"
        end
      end
      
      def render(constant, page)
        path = env.module_path(:doc, superclasses(constant), "#{page}.erb") {|file| File.exists?(file) }
        unless path
          raise "no such page: #{page.inspect} (#{constant.to_s})"
        end
        
        Templater.build_file(path, :app => app, :constant => constant)
      end
      
      def superclasses(constant)
        constant.ancestors - constant.included_modules
      end
    end
  end
end