module Ping
  class API < Grape::API
    format :json
    prefix "ping"

    get 'ping' do
      { ping: 'pong' }
    end
  end
end
