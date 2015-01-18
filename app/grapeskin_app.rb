require 'uri'
gem 'activesupport'

DEFAULT_CONFIG = {
	grape_paths: ['grapes'],
  error_log: 'error.log',
  access_log: 'access.log'
}

if appyml = YAML.load(File.read(File.expand_path('config/config.yml', File.join(File.dirname(__FILE__), '..')))) rescue nil
	CONFIG = DEFAULT_CONFIG.merge appyml.symbolize_keys
else
	CONFIG = DEFAULT_CONFIG.clone
end

Logger.class_eval { alias :write :'<<' }

access_log = File.new( File.expand_path(CONFIG[:access_log], File.join(File.dirname(__FILE__), '..')), 'a+' )
access_log.sync = true
CONFIG[:access_log] = access_log
CONFIG[:access_logger] = Logger.new( access_log, 10, 10490000)

error_log = File.new( File.expand_path(CONFIG[:error_log], File.join(File.dirname(__FILE__), '..')), 'a+' )
error_log.sync = true
CONFIG[:error_log] = error_log
CONFIG[:error_logger] = Logger.new(CONFIG[:error_log],10,10490000)
CONFIG[:error_logger].level = CONFIG[:error_logger_level] || ::Logger::INFO


String.class_eval do

  # stolen from ActiveSupport and simplified
  # By default, +camelize+ converts strings to UpperCamelCase. If the argument
  # to +camelize+ is set to <tt>:lower</tt> then +camelize+ produces
  # lowerCamelCase.
  #
  # +camelize+ will also convert '/' to '::' which is useful for converting
  # paths to namespaces.
  #
  #   'active_model'.camelize                # => "ActiveModel"
  #   'active_model'.camelize(:lower)        # => "activeModel"
  #   'active_model/errors'.camelize         # => "ActiveModel::Errors"
  #   'active_model/errors'.camelize(:lower) # => "activeModel::Errors"
  #
  # As a rule of thumb you can think of +camelize+ as the inverse of
  # +underscore+, though there are cases where that does not hold:
  #
  #   'SSLError'.underscore.camelize # => "SslError"
  def camelize(term=self)
    string = term.to_s
    string = string.sub(/^[a-z\d]*/) {
      #inflections.acronyms[$&] ||
      $&.capitalize
    }
    string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
    string.gsub!(/\//, '::')
    string
  end

  # stolen from ActiveSupport
  # Tries to find a constant with the name specified in the argument string.
  #
  #   'Module'.constantize     # => Module
  #   'Test::Unit'.constantize # => Test::Unit
  #
  # The name is assumed to be the one of a top-level constant, no matter
  # whether it starts with "::" or not. No lexical context is taken into
  # account:
  #
  #   C = 'outside'
  #   module M
  #     C = 'inside'
  #     C               # => 'inside'
  #     'C'.constantize # => 'outside', same as ::C
  #   end
  #
  # NameError is raised when the name is not in CamelCase or the constant is
  # unknown.
  def constantize(camel_cased_word=self)
    names = camel_cased_word.split('::')

    # Trigger a built-in NameError exception including the ill-formed constant in the message.
    Object.const_get(camel_cased_word) if names.empty?

    # Remove the first blank element in case of '::ClassName' notation.
    names.shift if names.size > 1 && names.first.empty?

    names.inject(Object) do |constant, name|
      if constant == Object
        constant.const_get(name)
      else
        candidate = constant.const_get(name)
        next candidate if constant.const_defined?(name, false)
        next candidate unless Object.const_defined?(name)

        # Go down the ancestors to check if it is owned directly. The check
        # stops when we reach Object or the end of ancestors tree.
        constant = constant.ancestors.inject do |const, ancestor|
          break const    if ancestor == Object
          break ancestor if ancestor.const_defined?(name, false)
          const
        end

        # owner is in Object, so raise
        constant.const_get(name, false)
      end
    end
  end

  # Tries to find a constant with the name specified in the argument string.
  #
  #   'Module'.safe_constantize     # => Module
  #   'Test::Unit'.safe_constantize # => Test::Unit
  #
  # The name is assumed to be the one of a top-level constant, no matter
  # whether it starts with "::" or not. No lexical context is taken into
  # account:
  #
  #   C = 'outside'
  #   module M
  #     C = 'inside'
  #     C                    # => 'inside'
  #     'C'.safe_constantize # => 'outside', same as ::C
  #   end
  #
  # +nil+ is returned when the name is not in CamelCase or the constant (or
  # part of it) is unknown.
  #
  #   'blargle'.safe_constantize  # => nil
  #   'UnknownModule'.safe_constantize  # => nil
  #   'UnknownModule::Foo::Bar'.safe_constantize  # => nil
  def safe_constantize(camel_cased_word=self)
    constantize(camel_cased_word)
  rescue NameError => e
    raise if e.name && !(camel_cased_word.to_s.split("::").include?(e.name.to_s) ||
      e.name.to_s == camel_cased_word.to_s)
  rescue ArgumentError => e
    raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
  end
end

module Grapeskin
  class App

    def initialize(aConfig=nil)
      @config = aConfig || {}
      # @filenames = ['', '.html', 'index.html', '/index.html']
      # @rack_static = ::Rack::Static.new(
      #   lambda { [404, {}, []] },
      #   root: File.expand_path('../../public', __FILE__),
      #   urls: ['/']
      #   )
    end

    def call(env)
      env['rack.errors'] = @config[:error_log] if @config[:error_log]
      env['rack.logger'] = @config[:error_logger] if @config[:error_logger]
      path = env['PATH_INFO']
      parts = path.split('/').delete_if {|s| s==''}
      app_name = parts[0]

      return error(errors: ["no grape_paths"], status: 501) unless @config[:grape_paths] && @config[:grape_paths].length>0
      api_path = nil
      @config[:grape_paths].each do |p|
        p = File.expand_path(p, File.dirname(__FILE__)+'/..')
        ap = File.join(p,"#{app_name}/api.rb")
        api_path = ap and break if File.exists? ap
      end
      return error() unless api_path
      require api_path
      class_name = "#{app_name.camelize}::API"
      cls = class_name.safe_constantize or return error(errors: ["#{class_name} class not found"], status: 501)
      #cls.prefix("/#{app_name}")
      #cls.endpoints.each {|e| e.options[:path] ||= "/#{app_name}"
      cls.call(env)
    end

    # !!! Maybe we should move Rack::Cors into the Apis, and support standard rack apps (not just Grape) eg. Rack::Builder apps
    def self.stack(aConfig)
      # Rack::Builder.new do
      #   use Rack::Cors, debug: true, logger: Logger.new(STDOUT) do
      #     allow do
      #       origins '*'
      #       resource '*', headers: :any, methods: [:get, :post]
      #     end
      #   end
      #   run Grapeskin::App.new
      # end.to_app

      # class MyLoggerMiddleware
      #   def initialize(app, logger)
      #     @app, @logger = app, logger
      #   end
      #   def call(env)
      #     env['mylogger'] = @logger
      #     @app.call(env)
      #   end
      # end

      Rack::Builder.new do
        use Rack::Cors, debug: true, logger: aConfig[:error_logger] do
          allow do
            origins '*'
            resource '*', headers: :any, methods: [:get, :post]
          end
        end
        use Rack::CommonLogger, aConfig[:access_logger]
        run Rack::ShowExceptions
        run Grapeskin::App.new(aConfig)
      end.to_app
    end

    ERROR_DEFAULTS = {
      status: 404,
      message: 'unknown',
      errors: nil,
    }
    def error(aOptions={})
      options = ERROR_DEFAULTS.merge(aOptions)
      Rack::Response.new(options.to_json, options[:status])
    end

  end
end
