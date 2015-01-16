require 'logger'

ENV['RACK_ENV'] ||= 'test'

DEFAULT_CONFIG = {
	grape_paths: ['grapes']
}

if appyml = YAML.load(File.read(File.expand_path('config.yml', File.dirname(__FILE__)))) rescue nil
	CONFIG = DEFAULT_CONFIG.merge appyml.symbolize_keys
else
	CONFIG = DEFAULT_CONFIG.clone
end


Logger.class_eval { alias :write :'<<' }
access_log = File.join( File.dirname(File.expand_path(__FILE__)), '..', 'application.log' )
CONFIG[:access_logger] = Logger.new( access_log, 10, 10490000)
error_logger      = File.new( File.join(File.dirname(File.expand_path(__FILE__)), '..', 'error.log'), 'a+' )
error_logger.sync = true
CONFIG[:error_logger] = error_logger

require File.expand_path('../application', __FILE__)
