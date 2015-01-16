require 'spec_helper'

describe Grapeskin::App do
  include Rack::Test::Methods

  def app
    Grapeskin::App.new
  end

  context 'routing' do
    it 'loads test class and executes' do
	    get '/ping/ping'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include 'pong'
    end
    it 'handles missing app as 404' do
	    get '/blah'
      expect(last_response.status).to eq(404)
    end
  end
end
