require 'test/unit'
require 'thread'
require_relative '../../ext/thread_local_config'

class ThreadLocalConfigTest < Test::Unit::TestCase
  include ExtmkHelper

  def dummy_obj(name = 'dummy')
    obj = Object.new
    obj.singleton_class.class_eval do
      define_method(:inspect) do
        "#<Object:0x%x (%s)>" % [object_id, name]
      end
    end
    obj
  end

  def test_fake_identity_to_original
    obj = dummy_obj
    $tlc_var = obj
    untrace = ThreadLocalConfig.hook_gvar(:$tlc_var)

    begin
      assert_equal obj, $tlc_var
      assert !(obj != $tlc_var)
      assert_equal obj.object_id, $tlc_var.object_id
      assert_equal obj.class, $tlc_var.class
      assert obj.eql?($tlc_var)
    ensure
      untrace.()
    end
  end

  def test_fake_identity_to_tlc
    obj = dummy_obj
    $tlc_var1 = $tlc_var2 = obj
    untrace1 = ThreadLocalConfig.hook_gvar(:$tlc_var1)
    untrace2 = ThreadLocalConfig.hook_gvar(:$tlc_var2)

    begin
      assert_equal $tlc_var1, $tlc_var2
      assert !($tlc_var1 != $tlc_var2)
      assert_equal $tlc_var1.object_id, $tlc_var2.object_id
      assert_equal $tlc_var1.class, $tlc_var2.class
      assert $tlc_var1.eql?($tlc_var2)
    ensure
      untrace1.()
      untrace2.()
    end
  end

  def test_assignment
    obj = dummy_obj("dummy 1")
    $tlc_var = obj
    untrace = ThreadLocalConfig.hook_gvar(:$tlc_var)

    begin
      obj2 = dummy_obj("dummy 2")
      $tlc_var = obj2

      assert_equal obj2, $tlc_var
      assert !(obj2 != $tlc_var)
      assert_equal obj2.object_id, $tlc_var.object_id
      assert_equal obj2.class, $tlc_var.class
      assert obj2.eql?($tlc_var)
    ensure
      untrace.()
    end
  end

  def test_thread_local
    obj = dummy_obj("dummy 1")
    $tlc_var = obj
    untrace = ThreadLocalConfig.hook_gvar(:$tlc_var)

    begin
      mu = Mutex.new
      cond = ConditionVariable.new
      th = Thread.new do
        mu.synchronize {
          obj2 = dummy_obj("dummy 2")
          $tlc_var = obj2
          cond.signal
        }
      end

      begin
        mu.synchronize {
          cond.wait(mu)
          assert $tlc_var.kind_of?(ThreadLocalConfig)
          assert_equal obj, $tlc_var
          assert !(obj != $tlc_var)
          assert_equal obj.object_id, $tlc_var.object_id
          assert_equal obj.class, $tlc_var.class
          assert obj.eql?($tlc_var)
        }
      ensure
        th.join
      end
    ensure
      untrace.()
    end
  end

  def test_fake_identity_to_original_const
    obj = []
    self.class.const_set(:LIBS, obj)
    begin
      ThreadLocalConfig.hook_const(self.class, :LIBS)

      assert LIBS.kind_of?(ThreadLocalConfig)
      assert_equal obj, LIBS
      assert !(obj != LIBS)
      assert_equal obj.object_id, LIBS.object_id
      assert_equal obj.class, LIBS.class
      assert obj.eql?(LIBS)
    ensure
      self.class.class_eval do
        remove_const(:LIBS)
      end
    end
  end

  def test_modify_const
    obj = []
    self.class.const_set(:LIBS, obj)
    begin
      ThreadLocalConfig.hook_const(self.class, :LIBS)

      LIBS << "libc" << "libm"

      assert_equal obj, LIBS
      assert !(obj != LIBS)
      assert obj.eql?(LIBS)
    ensure
      self.class.class_eval do
        remove_const(:LIBS)
      end
    end
  end
end
