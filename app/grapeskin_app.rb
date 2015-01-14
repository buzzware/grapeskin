require 'uri'

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
    def initialize
      # @filenames = ['', '.html', 'index.html', '/index.html']
      # @rack_static = ::Rack::Static.new(
      #   lambda { [404, {}, []] },
      #   root: File.expand_path('../../public', __FILE__),
      #   urls: ['/']
      #   )
    end

    def self.instance
      @instance ||= Rack::Builder.new do
        use Rack::Cors do
          allow do
            origins '*'
            resource '*', headers: :any, methods: :get
          end
        end

        run Grapeskin::App.new
      end.to_app
    end

    def call(env)
      puts env.inspect

      path = env['PATH_INFO']
      parts = path.split('/').delete_if {|s| s==''}
      app_name = parts[0]

      require "#{app_name}/api"
      cls = "#{app_name.camelize}::API".safe_constantize
      #cls.prefix("/#{app_name}")
      #cls.endpoints.each {|e| e.options[:path] ||= "/#{app_name}"

      cls.call(env)
    end

    # api
    # response = Grapeskin::API.call(env)

    # # Check if the App wants us to pass the response along to others
    # if response[1]['X-Cascade'] == 'pass'
    #   # static files
    #   request_path = env['PATH_INFO']
    #   @filenames.each do |path|
    #     response = @rack_static.call(env.merge('PATH_INFO' => request_path + path))
    #     return response if response[0] != 404
    #   end
    # end
    #
    # # Serve error pages or respond with API response
    # case response[0]
    # when 404, 500
    #   content = @rack_static.call(env.merge('PATH_INFO' => "/errors/#{response[0]}.html"))
    #   [response[0], content[1], content[2]]
    # else
    #  response
    # end
  end
end
