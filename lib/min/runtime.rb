module Min
  class BootstrapError < StandardError; end
  
  class Runtime
    attr_reader :context, :load_path, :parser
    
    def initialize
      @parser    = Parser.new
      @context   = Context.new(nil)
      @load_path = [File.dirname(__FILE__) + "/../../kernel"]
    end
    
    def [](name)
      @context[name]
    end
    
    def []=(name, value)
      @context[name] = value
    end
    
    def eval(string, context=@context)
      @parser.parse(string).eval(context)
    end
    
    def load(file)
      path = find_file_in_load_path(file) || raise("File not found: #{file}")
      eval File.read(path)
    end
    
    def bootstrap
      vtable = self[:VTable] = VTable.new
      vtable.vtable = vtable
      
      object_vt = VTable.new
      object_vt.vtable = vtable
      vtable.parent = object_vt
      object = self[:Object] = object_vt.allocate
      
      # Base classes bootstrap
      [
        Min::RubyMethod,
        Min::VTable,
        Min::Object,
        Min::Number,
        Min::String,
        Min::Symbol,
        Min::Array,
        Min::Hash,
        Min::Closure
      ].each { |c| c.bootstrap(self) }
      
      # Root context init
      self[:self] = @context.min_self = object.vtable.allocate
      
      # Load kernel
      load "bootstrap"
    end
    
    private
      def find_file_in_load_path(file)
        if path = @load_path.detect { |path| File.file?("#{path}/#{file}.min") }
          "#{path}/#{file}.min"
        end
      end
  end
  
  class << self
    def bootstrap(runtime_class = Runtime)
      @runtime = runtime_class.new
      @runtime.bootstrap
    end
    
    def runtime
      raise BootstrapError, "Runtime not bootstrapped" unless @runtime
      @runtime
    end
    
    # Delegates
    [:[], :eval, :load].each { |method| define_method(method) { |*a| runtime.send(method, *a) } }
  end
end
