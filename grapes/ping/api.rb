module Ping
  class API < Grape::API
    format :json
    prefix "ping"

    get 'ping' do
      { ping: 'pong' }
    end

    get 'bang' do
      raise "Bang!"
    end
  end
end
