require 'rubygems'
gem 'activeresource', '=3.2.17'
gem 'activesupport', '=3.2.17'
require 'active_support'
require 'active_resource'

# A neat ruby library for interacting with the RESTfull API of billomat
module Billomat

  class << self
    attr_accessor :email, :password, :host_format, :domain_format, :protocol, :port, :api_path
    attr_reader :account, :key

    # Sets the account name and updates all resources with the new domain
    def account=(name)
      resources.each do |klass|
        klass.site = klass.site_format % (host_format % [protocol, domain_format % name, ":#{port}", api_path])
      end
      @account = name
    end

    # Sets up basic authentication credentials for all resources.
    # Removes all earlier authentication info
    def authenticate (email,password)
      resources.each do |klass|
        klass.email = email
        klass.password = password
        klass.headers.delete 'X-BillomatApiKey'
      end
      @email = email
      @password = password
      @key = nil
    end

    # Sets the api key for all resource
    # Removes all earlier authentication info
    def key=(value)
      resources.each do |klass|       
        klass.headers['X-BillomatApiKey'] = value
        klass.headers['Accept'] = 'application/json' # hack :-(
      end
      @key = value
      @email = nil
      @password = nil
    end

    # Validates connection
    # returns true when valid false when not
    def validate
      validate! rescue false
    end

    # Same as validate
    # but raises http-error when connection is invalid
    def validate!
      if Billomat.account.nil?
        raise 'No Account set, use Billomat.account='
      end
      if !Billomat.key.nil? || ( !Billomat.email.nil? && !Billomat.password.nil? )
        !!Billomat::Myself.find
      else
        raise 'No authentication info set, set either Billomat.key XOR use Billomat.authenticate(email, password)'
      end
    end

    def resources
      @resources ||= []
    end
  end

  self.host_format   = '%s://%s%s%s' # protocol :// domain_format port path
  #self.domain_format = '%s.billomat.net'
  self.domain_format = 'localhost'
  self.api_path      = '/api'
  self.protocol      = 'http'
  #self.port          = '80'
  self.port          = '8081'

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

  module ResourceWithoutId
    def save
    connection.put(element_path(prefix_options), encode, self.class.headers).tap do |response|
      load_attributes_from_response(response)
    end
  end
  end

  # possibly ResourceWithActiveArchived

  class Base < ActiveResource::Base
    class << self

      # TODO somehow use json http://www.billomat.com/de/api/grundlagen

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

      def element_path(id, prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}/#{id}#{query_string(query_options)}"
      end

      def el_p(id,prefix_options = {}, query_options = nil)
        element_path(id,prefix_options, query_options)
      end

      def coll_p(prefix_options = {}, query_options = nil)
        collection_path(prefix_options, query_options)
      end

  

      def collection_path(prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}#{query_string(query_options)}"
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

    include ResourceWithoutId

    class << self
      def collection_name
        element_name
      end

      def element_path(id,prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}#{query_string(query_options)}"
      end

      def collection_path(prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}#{query_string(query_options)}"
      end
    end

    def find
      # TODO: Fetch whether ids where given or not
      # and get the wanted one in those cases
      super(1)
    end

    def self.first
      self.find
    end

    def self.last
      self.find
    end

    alias_method :first, :find
    alias_method :last, :find

    # Prevent collection methods
    def self.all
      raise MethodNotAvailable, "Method not supported on #{self.class.name}"
    end
  end

  class ReadOnlySingletonBase < SingletonBase
    include ResourceWithoutWriteAccess
  end
end

module ActiveResource
  module Formats
    module JsonFormat
      def decode(json)
        formatted = Formats.remove_root(ActiveSupport::JSON.decode(json)).except('@page', '@per_page', '@total')
        Formats.remove_root formatted
      end
    end
  end
end

#$:.unshift(File.dirname(__FILE__))
#Dir[File.join(File.dirname(__FILE__), "billomat/*.rb")].each { |f| require f }

require File.dirname(__FILE__) + '/billomat/settings'
require File.dirname(__FILE__) + '/billomat/articles'
require File.dirname(__FILE__) + '/billomat/invoice'
require File.dirname(__FILE__) + '/billomat/offer'
require File.dirname(__FILE__) + '/billomat/reminder'
require File.dirname(__FILE__) + '/billomat/template'
require File.dirname(__FILE__) + '/billomat/role'
require File.dirname(__FILE__) + '/billomat/users'
require File.dirname(__FILE__) + '/billomat/myself'
require File.dirname(__FILE__) + '/billomat/clients'
require File.dirname(__FILE__) + '/billomat/unit'
