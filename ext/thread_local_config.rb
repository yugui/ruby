module ExtmkHelper
  class ThreadLocalConfig < BasicObject
    def initialize(name, value)
      @name = name.to_sym
      ::Thread.current[@name] = value
    end
    class << self
      private :new
    end

    def p(*args)
      ::Object.send :p, *args
    end

    def inspect
      "#<ThreadLocalConfig: %s>" % __tlc_value.inspect
    end

    def self.hook_gvar(name)
      name = name.to_s
      raise ::NameError, "invalid global variable name #{name}" unless name[/\A\$.+\z/]
      config = new(name, eval(name))
      eval("->(val) { #{name} = val }")[config]

      raise ::NameError, "variable #{name} already traced" unless untrace_var(name).empty?
      t = trace_var(name) do |val|
        return if config.equal?(val)
        config.__tlc_value = val
        eval("->(val) { #{name} = val }")[config]
      end

      -> { untrace_var(name) }
    end

    def self.hook_const(mod = Object, name)
      name = name.to_s
      raise ::NameError, "invalid constant name #{name}" unless name[/\A\$[A-Z]\w*\z/]
      config = new(name, mod.const_get(name))
      mod.send(:remove_const, name)
      mod.const_set(name, config)
    end

    def __tlc_value=(value)
      ::Thread.current[@name] = value
    end

    def __tlc_value
      ::Thread.current[@name]
    end

    def kind_of?(mod)
      if mod == ThreadLocalConfig
        true
      else
        super
      end
    end

    def ==(rhs)
      __tlc_value == rhs
    end

    def method_missing(msg, *args, &blk)
      __tlc_value.__send__(msg, *args, &blk)
    end
  end
  Object.class_eval do
    orig = instance_method(:==)
    define_method(:==) do |rhs|
      if rhs.kind_of?(ExtmkHelper::ThreadLocalConfig)
        orig.bind(self).call(rhs.__tlc_value)
      else
        orig.bind(self).call(rhs)
      end
    end
    alias eql? ==
  end
end

if $0 == __FILE__
  o = Object.new
  cfg = ExtmkHelper::ThreadLocalConfig.new(:hoge, o)
  p o == o
  #p cfg.kind_of?(Object)
  #p cfg.kind_of?(ExtmkHelper::ThreadLocalConfig)
  p o == cfg
end
