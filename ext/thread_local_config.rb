require 'forwardable'
module ExtmkHelper
  class MkmfContext
    extend Forwardable
    def initialize
      @values = {}
    end

    def_delegators(:@values, :[], :[]=)

    attr_reader :values
    protected :values

    def dup
      copy = MkmfContext.new
      self.values.each do |k, v|
        copy.values[k] = v.dup
      end
      copy
    end
  end

  class ThreadLocalConfig < BasicObject
    def initialize(name, value)
      @name = name.to_sym
      value.class.include IdentityHelper
      ::Thread.mkmf_context[@name] = value
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
        next if config.equal?(val)
        # NOTE: race condition since the assignment happens until this re-installation gets done.
        # TODO(yugui) reimplement with rb_define_hooked_variable in dmyext.c.
        eval("->(val) { #{name} = val }")[config]
        config.__tlc_value = val
      end

      -> { untrace_var(name) }
    end

    def self.hook_const(mod = Object, name)
      name = name.to_s
      raise ::NameError, "invalid constant name #{name}" unless name[/\A[A-Z]\w*\z/]
      config = new(name, mod.const_get(name))
      mod.send(:remove_const, name)
      mod.const_set(name, config)
    end

    def __tlc_value=(value)
      value.class.include IdentityHelper
      ::Thread.mkmf_context[@name] = value
    end

    def __tlc_value
      ::Thread.mkmf_context[@name]
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

  module IdentityHelper
    # TODO(yugui) We can simply use Module#prepend once BASERUBY stops supporting Ruby 1.9.3 or earlier.
    def self.included(mod)
      mod.module_eval do
        [ :==, :eql? ].each do |msg|
          orig = instance_method(msg)
          define_method(msg) do |rhs|
            if rhs.kind_of?(ExtmkHelper::ThreadLocalConfig)
              orig.bind(self).call(rhs.__tlc_value)
            else
              orig.bind(self).call(rhs)
            end
          end
        end
      end
    end
  end
end

class Thread
  def self.set_mkmf_context(context)
    current[:__mkmf_context] = context
  end

  def self.mkmf_context
    current[:__mkmf_context]
  end
end
