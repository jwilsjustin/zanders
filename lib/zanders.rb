require "zanders/version"

require 'net/ftp'
require 'savon'

require 'zanders/base'
require 'zanders/soap_client'

require 'zanders/user'
require 'zanders/address'
require 'zanders/order'
require 'zanders/item'
require 'zanders/inventory'
require 'zanders/catalog'

module Zanders

  ADDRESS_API_URL = 'https://shop2.gzanders.com/webservice/shiptoaddresses?wsdl'
  ORDER_API_URL   = 'https://shop2.gzanders.com/webservice/orders?wsdl'
  ITEM_API_URL    = 'https://shop2.gzanders.com/webservice/items?wsdl'

  class NotAuthenticated < StandardError; end

  class << self
    attr_accessor :config
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end

  class Configuration
    attr_accessor :debug_mode
    attr_accessor :file_encoding
    attr_accessor :ftp_host
    attr_accessor :ftp_directory

    alias debug_mode? debug_mode

    def initialize
      @debug_mode    ||= false
      @file_encoding ||= 'Windows-1252'
      @ftp_host      ||= 'ftp2.gzanders.com'
      @ftp_directory ||= 'Inventory/AmmoReady'
    end
  end
end
