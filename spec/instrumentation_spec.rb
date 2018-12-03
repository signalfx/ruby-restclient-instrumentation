require 'spec_helper'

RSpec.describe RestClient::Instrumentation do
  describe "Class Methods" do
    it { should respond_to :instrument }
  end

  let (:tracer) { OpenTracingTestTracer.build }
  let (:url) { "http://www.example.com/" }

  before do
    OpenTracing.global_tracer = tracer
    RestClient::Instrumentation.instrument(tracer: tracer, propagate: true)
  end

  describe :instrument do
    it "patches the class's execute method" do
      expect(RestClient::Request.new(method: :get, url: url)).to respond_to(:execute_original)
    end

    it "patches the class's transmit method" do
      expect(RestClient::Request.new(method: :get, url: url)).to respond_to(:transmit_original)
    end
  end

  describe "RestClient instrumentation" do
    let (:request) { RestClient::Request.new(method: :get, url: url) }
    let (:net_response) { Net::HTTPResponse.new(nil, 200, "message") }
    let (:response) { RestClient::Response.create("body", net_response, request)}

    # clear the tracer spans after each test
    after do
      tracer.spans.clear
    end

    it 'calls the original execute method' do
      allow_any_instance_of(RestClient::Request).to receive(:execute_original).and_return(response)
      expect_any_instance_of(RestClient::Request).to receive(:execute_original)

      RestClient::Request.execute(method: :get, url: url)

      expect(response.code).to eq 200
    end

    context 'when execute is called' do
      before do
        allow_any_instance_of(RestClient::Request).to receive(:execute_original).and_return(response)

        RestClient::Request.execute(method: :get, url: url)
      end

      let (:span) { tracer.spans.last }

      it 'adds a span to the tracer' do
        expect(tracer.spans.count).to eq 1
      end

      it 'adds a span.kind tag' do
        expect(span.tags.fetch('span.kind')).to eq 'client'
      end

      it 'adds a http.method tag' do
        expect(span.tags.fetch('http.method')).to eq 'get'
      end

      it 'adds a http.url tag' do
        expect(span.tags.fetch('http.url')).to eq url
      end

      it 'adds a http.status_code tag' do
        expect(span.tags.fetch('http.status_code')).to eq 200
      end
    end

    context 'when transmit is called' do
      it 'injects the span context' do
        # create a new request to test propagation
        propagate_request = RestClient::Request.new(method: :get, url: url)
        expect(propagate_request).to respond_to(:transmit_original) # sanity check

        allow(propagate_request).to receive(:transmit_original) do |uri, req, payload, &block|
          fake_request = RestClient::Request.new(method: :get, url: url)

          # ugly way of getting the span headers from this method. req is a Net::HTTP::Request,
          # but RestClient::Response.create wants a RestClient::Request.
          # It does take a Net::HTTPResponse, so copy in the outgoing headers so we can test
          net_response = Net::HTTPResponse.new(nil, 200, "message")
          net_response['span_id'] = req['test-traceid']
          net_response['trace_id'] = req['test-spanid']

          # create our doctored response with the necessary headers
          RestClient::Response.create("body", net_response, fake_request)
        end

        # we only care about the doctored Net::HTTPResponse with the headers to test
        net_response = propagate_request.execute.net_http_res
        span = tracer.spans.last

        # test for the span headers
        expect(span.context.trace_id).to eq net_response['trace_id']
        expect(span.context.span_id).to eq net_response['span_id']
      end
    end
  end
end
