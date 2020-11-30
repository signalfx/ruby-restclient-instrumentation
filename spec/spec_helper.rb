require 'bundler/setup'
require 'restclient'
require 'restclient/instrumentation'
require 'signalfx_test_tracer'
require 'webmock/rspec'

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
