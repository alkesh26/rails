# frozen_string_literal: true

require_relative "abstract_unit"
require "pp"
require "active_support/dependencies"
require_relative "dependencies_test_helpers"

module ModuleWithMissing
  mattr_accessor :missing_count
  def self.const_missing(name)
    self.missing_count += 1
    name
  end
end

module ModuleWithConstant
  InheritedConstant = "Hello"
end

class DependenciesTest < ActiveSupport::TestCase
  include DependenciesTestHelpers

  setup do
    @loaded_features_copy = $LOADED_FEATURES.dup
    $LOAD_PATH << "test"
  end

  teardown do
    ActiveSupport::Dependencies.clear
    $LOADED_FEATURES.replace(@loaded_features_copy)
    $LOAD_PATH.pop
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raise(LoadError) { require_dependency("missing_service") }
  end

  def test_unloadable
    with_autoloading_fixtures do
      Object.const_set :M, Module.new
      M.unloadable

      ActiveSupport::Dependencies.clear
      assert_not defined?(M)

      Object.const_set :M, Module.new
      ActiveSupport::Dependencies.clear
      assert_not defined?(M), "Dependencies should unload unloadable constants each time"
    end
  end

  def test_unloadable_should_fail_with_anonymous_modules
    with_autoloading_fixtures do
      m = Module.new
      assert_raise(ArgumentError) { m.unloadable }
    end
  end

  def test_unloadable_should_return_change_flag
    with_autoloading_fixtures do
      Object.const_set :M, Module.new
      assert_equal true, M.unloadable
      assert_equal false, M.unloadable
    end
  ensure
    remove_constants(:M)
  end

  def test_unloadable_constants_should_receive_callback
    Object.const_set :C, Class.new { def self.before_remove_const; end }
    C.unloadable
    assert_called(C, :before_remove_const, times: 1) do
      assert_respond_to C, :before_remove_const
      ActiveSupport::Dependencies.clear
      assert_not defined?(C)
    end
  ensure
    remove_constants(:C)
  end

  def test_hook_called_multiple_times
    assert_nothing_raised { ActiveSupport::Dependencies.hook! }
  end
end
