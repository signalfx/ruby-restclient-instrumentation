require "opentracing"
require "restclient"
require "restclient/instrumentation/version"

module RestClient
  module Instrumentation
    class << self

      attr_accessor :tracer

      def instrument(tracer: OpenTracing.global_tracer, propagate:)
        @tracer = tracer

        patch_request
        patch_transmit if propagate
      end

      def patch_request

        ::RestClient::Request.class_eval do
          alias_method :execute_original, :execute if !self.method_defined? :execute_original

          def execute(&block)
            tags = {
              'span.kind' => 'client',
              'http.method' => method,
              'http.url' => url,
            }

            result = nil

            span = ::RestClient::Instrumentation.tracer.start_span("restclient.execute", tags: tags)
            begin
              # make this available to the transmit method to inject the context
              @span_context = span.context

              result = execute_original(&block)

              span.set_tag("http.status_code", result.code)
            rescue => error
              span.set_tag("http.status_code", error.http_code)
              span.set_tag("error", true)
              span.log_kv(key: "message", value: error.message)

              # pass this along for the original caller to handle
              raise error
            ensure
              span.finish()
            end

            result
          end # execute
        end # module_eval
      end # patch_request

      def patch_transmit
        ::RestClient::Request.class_eval do

          alias_method :transmit_original, :transmit if !self.method_defined? :transmit_original

          def transmit(uri, req, payload, &block)
            ::RestClient::Instrumentation.tracer.inject(@span_context, OpenTracing::FORMAT_RACK, req) if @span_context

            transmit_original(uri, req, payload, &block)
          end # transmit
        end # class_eval
      end # patch_transmit
    end # class << self
  end # module Instrumentation
end # module RestClient
