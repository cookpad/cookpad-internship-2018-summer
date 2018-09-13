# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

require 'capybara/rspec'

ActiveRecord::Migration.maintain_test_schema!

class FakeDriver < Capybara::Driver::Base
  def needs_server?
    true
  end
end

Capybara.register_driver :fake do |app|
  FakeDriver.new
end

Capybara.default_driver = :fake

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.filter_rails_from_backtrace!
end
