require 'spec_helper'

describe Grapeskin::App do
  include Rack::Test::Methods

  def app
    Grapeskin::App.instance
  end

  context 'routing' do
    it 'loads test class and executes' do
	    get '/ping/ping'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include 'pong'
    end
  end
end
