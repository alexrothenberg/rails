require 'abstract_unit'
require 'generators/generators_test_helper'
require 'rails/generators/rails/plugin_new/plugin_new_generator'
require 'generators/shared_generator_tests.rb'

DEFAULT_PLUGIN_FILES = %w(
  .gitignore
  Gemfile
  Rakefile
  bukkits.gemspec
  MIT-LICENSE
  lib
  lib/bukkits.rb
  lib/tasks/bukkits_tasks.rake
  script/rails
  test/bukkits_test.rb
  test/test_helper.rb
  test/dummy
)

class PluginNewGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  destination File.join(Rails.root, "tmp/bukkits")
  arguments [destination_root]
  include SharedGeneratorTests

  def default_files
    ::DEFAULT_PLUGIN_FILES
  end

  def test_invalid_plugin_name_raises_an_error
    content = capture(:stderr){ run_generator [File.join(destination_root, "43-things")] }
    assert_equal "Invalid plugin name 43-things. Please give a name which does not start with numbers.\n", content
  end

  def test_invalid_plugin_name_is_fixed
    run_generator [File.join(destination_root, "things-43")]
    assert_file "things-43/lib/things-43.rb", /module Things43/
  end

  def test_generating_test_files
    run_generator
    assert_file "test/test_helper.rb"
    assert_file "test/bukkits_test.rb", /assert_kind_of Module, Bukkits/
  end

  def test_generating_test_files_in_full_mode
    run_generator [destination_root, "--full"]
    assert_directory "test/integration/"

    assert_file "test/integration/navigation_test.rb", /ActionDispatch::IntegrationTest/
  end

  def test_ensure_that_plugin_options_are_not_passed_to_app_generator
    FileUtils.cd(Rails.root)
    assert_no_match /It works from file!.*It works_from_file/, run_generator([destination_root, "-m", "lib/template.rb"])
  end

  def test_ensure_that_test_dummy_can_be_generated_from_a_template
    FileUtils.cd(Rails.root)
    run_generator([destination_root, "-m", "lib/create_test_dummy_template.rb", "--skip-test-unit"])
    assert_file "spec/dummy"
    assert_no_file "test"
  end

  def test_database_entry_is_assed_by_default_in_full_mode
    run_generator([destination_root, "--full"])
    assert_file "test/dummy/config/database.yml", /sqlite/
    assert_file "Gemfile", /^gem\s+["']sqlite3-ruby["'],\s+:require\s+=>\s+["']sqlite3["']$/
  end

  def test_config_another_database
    run_generator([destination_root, "-d", "mysql", "--full"])
    assert_file "test/dummy/config/database.yml", /mysql/
    assert_file "Gemfile", /^gem\s+["']mysql2["']$/
  end

  def test_active_record_is_removed_from_frameworks_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_file "test/dummy/config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
  end

  def test_ensure_that_skip_active_record_option_is_passed_to_app_generator
    run_generator [destination_root, "--skip_active_record"]
    assert_no_file "test/dummy/config/database.yml"
    assert_no_match /ActiveRecord/, File.read(File.join(destination_root, "test/test_helper.rb"))
  end

  def test_ensure_that_database_option_is_passed_to_app_generator
    run_generator [destination_root, "--database", "postgresql"]
    assert_file "test/dummy/config/database.yml", /postgres/
  end

  def test_ensure_that_javascript_option_is_passed_to_app_generator
    run_generator [destination_root, "--javascript", "jquery"]
    assert_file "test/dummy/public/javascripts/jquery.js"
  end

  def test_ensure_that_skip_javascript_option_is_passed_to_app_generator
    run_generator [destination_root, "--skip_javascript"]
    assert_no_file "test/dummy/public/javascripts/prototype.js"
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match /It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"])
  end

  def test_ensure_that_tests_works
    run_generator
    FileUtils.cd destination_root
    `bundle install`
    assert_match /1 tests, 1 assertions, 0 failures, 0 errors/, `bundle exec rake test`
  end

  def test_ensure_that_tests_works_in_full_mode
    run_generator [destination_root, "--full"]
    FileUtils.cd destination_root
    `bundle install`
    assert_match /2 tests, 2 assertions, 0 failures, 0 errors/, `bundle exec rake test`
  end

  def test_creating_engine_in_full_mode
    run_generator [destination_root, "--full"]
    assert_file "lib/bukkits/engine.rb", /module Bukkits\n  class Engine < Rails::Engine\n  end\nend/
    assert_file "lib/bukkits.rb", /require "bukkits\/engine"/
  end

  def test_being_quiet_while_creating_dummy_application
    assert_no_match /create\s+config\/application.rb/, run_generator
  end

  def test_create_mountable_application_with_mountable_option
    run_generator [destination_root, "--mountable"]
    assert_file "config/routes.rb", /Bukkits::Engine.routes.draw do/
    assert_file "lib/bukkits/engine.rb", /isolate_namespace Bukkits/
    assert_file "test/dummy/config/routes.rb", /mount Bukkits::Engine => "\/bukkits"/
    assert_file "app/controllers/bukkits/application_controller.rb", /module Bukkits\n  class ApplicationController < ActionController::Base/
    assert_file "app/helpers/bukkits/application_helper.rb", /module Bukkits\n  module ApplicationHelper/
  end

  def test_passing_dummy_path_as_a_parameter
    run_generator [destination_root, "--dummy_path", "spec/dummy"]
    assert_file "spec/dummy"
    assert_file "spec/dummy/config/application.rb"
    assert_no_file "test/dummy"
  end

  def test_skipping_gemspec
    run_generator [destination_root, "--skip-gemspec"]
    assert_no_file "bukkits.gemspec"
  end

protected

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end

end

class CustomPluginGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::PluginNewGenerator

  destination File.join(Rails.root, "tmp/bukkits")
  arguments [destination_root]
  include SharedCustomGeneratorTests

  def test_overriding_test_framework
    FileUtils.cd(destination_root)
    run_generator([destination_root, "-b", "#{Rails.root}/lib/plugin_builders/spec_builder.rb"])
    assert_file 'spec/spec_helper.rb'
    assert_file 'spec/dummy'
    assert_file 'Rakefile', /task :default => :spec/
    assert_file 'Rakefile', /# spec tasks in rakefile/
    assert_file 'script/rails', %r{spec/dummy}
  end

protected
  def default_files
    ::DEFAULT_PLUGIN_FILES
  end

  def builder_class
    :PluginBuilder
  end

  def builders_dir
    "plugin_builders"
  end

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end
end
