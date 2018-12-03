# Restclient::Instrumentation

This gem provides instrumentation for RestClient requests.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'restclient-instrumentation'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install restclient-instrumentation

## Usage

To enable the instrumentation and patch RestClient:

```ruby
require 'restclient/instrumentation'

RestClient::Instrumentation.instrument
```

`instrument` takes two parameters:
- `propagate`: Enable propagating span contexts through request headers.
  A value must be provided for this keyword argument
- `tracer`: (Optional) Set an OpenTracing tracer to use.
  Defaults to `OpenTracing.global_tracer`.

In the case of an error, the span will be finished and tagged with the error code and message. However, the exception will still be passed up to the caller, and the caller must handle it or at least wait as long as the exporter's flush interval to ensure that the span gets exported.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/signalfx/ruby-restclient-instrumentation.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
