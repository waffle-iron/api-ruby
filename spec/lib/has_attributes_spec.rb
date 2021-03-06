require 'spec_helper'

describe Conjur::HasAttributes do
  class ObjectWithAttributes
    include Conjur::HasAttributes

    def username; 'alice'; end
    def url; 'http://example.com/the-object'; end
  end

  def new_object
    ObjectWithAttributes.new
  end

  let(:object) { new_object }
  let(:attributes) { { 'id' => 'the-id' } }

  before {
    expect(object).to receive(:get).with(no_args).and_return(double(:response, body: attributes.to_json))
  }

  it "should fetch attributes from the server" do
    expect(object.attributes).to eq(attributes)
  end

  describe "caching" do
    let(:cache) {
      Struct.new(:dummy) do
        def table; @table ||= Hash.new; end

        def fetch_attributes cache_key, &block
          table[cache_key] || table[cache_key] = yield
        end
      end.new
    }

    around do |example|
      saved = Conjur.cache
      Conjur.cache = cache

      begin
        example.run
      ensure
        Conjur.cache = saved
      end
    end
    context "enabled" do
      it "caches the attributes across objects" do
        expect(object.attributes).to eq(attributes)
        expect(new_object.attributes).to eq(attributes)
        expect(cache.table).to eq({
          "alice.http://example.com/the-object" => attributes
        })
      end
    end
  end
end
