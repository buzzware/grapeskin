Grapeskin

An experimental Ruby Rack app that dynamically loads and executes correctly formed Ruby [Grape](http://intridea.github.io/grape/) APIs based on the url from an array of paths.

A Grape API looks like :

		module Ping
		  class API < Grape::API
		    format :json
		    prefix "ping"

		    get 'ping' do
		      { ping: 'pong' }
		    end
		  end
		end


A GET http://example.org/something/special request would load "Something::API" from "grapes/something/api.rb" and execute
the "special" handler.

This means :

1. The Grapeskin app consumes minimal memory by itself, because the APIs and their dependencies are not preloaded

1. The Grapeskin app can support any number of APIs from one install

1. API's can installed and removed and upgraded ad hoc simply by moving files in and out of a grapes path, without restarting the server

1. Performance is less than normal because each API and its dependencies must be loaded on each request

Enjoy!
