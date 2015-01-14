$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'app'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'boot'

Bundler.require :default, ENV['RACK_ENV']

CONFIG = {}
CONFIG[:grape_paths] = [File.expand_path('../grapes',File.dirname(__FILE__))]

# Dir[File.expand_path('../../api/*.rb', __FILE__)].each do |f|
#   require f
# end

#require 'api'
require 'grapeskin_app'
