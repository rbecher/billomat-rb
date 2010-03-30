require 'rubygems'
require 'active_support'
require 'active_resource'

# A neat ruby library for interacting with the RESTfull API of billomat

module Billomat

  class << self
    attr_accessor :email, :password, :host_format, :domain_format, :protocol, :port 
    attr_reader :account, :key

    # Sets the account name and updates all resources with the new domain
    def account=(name)
      resources.each do |klass|
        klass.site = klass.site_format % (host_format % [protocol, domain_format % name, ":#{port}"])
      end
      @account = name
    end

    # Sets up basic authentication credentials for all resources.
    def authenticate (email,password)
      resources.each do |klass|
        klass.email = email
        klass.password = password
      end
      @email = email
      @password = password
    end

    # Sets the api key for all resource
    def key=(value)
      resources.each do |klass|
        klass.headers['X-BillomatApiKey'] = value
      end
      @key = value
    end

    # Validates connection
    # returns true when valid false when not
    def validate
      validate! rescue false
    end

    # Same as validate
    # but raises http-error when connection is invalid
    def validate!
      !!Billomat::Account.find
    end

    def resources
      @resources ||= []
    end
  end

  self.host_format   = '%s://%s%s'
  self.domain_format = '%s.billomat.net'
  self.protocol      = 'http'
  self.port          = ''

  class MethodNotAvailable < StandardError; end

  module ResourceWithoutWriteAccess
    def save
      raise MethodNotAvailable, "Cannot save #{self.class.name} over billomat api"
    end

    def create
      raise MethodNotAvailable, "Cannot save #{self.class.name} over billomat api"
    end

    def destroy
      raise MethodNotAvailable, "Cannot save #{self.class.name} over billomat api"
    end
  end

  # possibly ResourceWithActiveArchived

  class Base < ActiveResource::Base
    class << self
      def inherited(base)
        unless base == Billomat::SingletonBase
          Billomat.resources << base
          class << base
            attr_accessor :site_format
          end
          base.site_format = '%s'
          base.timeout = 20
        end
        super
      end

      # Some common shortcuts from ActiveRecord

      def all(options={})
        find(:all,options)
      end

      def first(options={})
        find_every(options).first
      end

      def last(options={})
        find_every(options).last
      end
    end

    private

    def query_string?(options)
      options.is_a?(String) ? "#{options}" : super
    end
  end

  class SingletonBase < Base
    include ResourceWithoutWriteAccess

    class << self
      def collection_name
        element_name
      end

      def element_path(id,prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
      end

      def collection_path(prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
      end
    end

    def find
      super(1)
    end

    alias_method :first, :find
    alias_method :last, :find

    # Prevent collection methods
    def all
      raise MethodNotAvailable, "Method not supported on #{self.class.name}"
    end
  end
end

$:.unshift(File.dirname(__FILE__))
Dir[File.join(File.dirname(__FILE__), "billomat/*.rb")].each { |f| require f }