module Zanders
  class Order < SoapClient

    ##
    # == Order Service
    #
    # Return Codes
    # 0: Success
    # 1: Username and/or Password were incorrect
    # 2: There was a problem creating the order
    # 5: Cannot create order with no items
    # 9: Order not created because all items not available and not to be back ordered
    # 10: Ship date cannot be before today
    # 11: Ship date cannoy be more than 30days in the future
    # 21: The order number is NOT connected to your customer number
    # 31: Can NOT add item with quantity of less than 1
    # 41: The item number requested is NOT connected to this order

    attr_reader :username, :password, :options

    # Public: Initialize a new Order
    #
    # options - Hash of username, password, and address information
    #
    # Returns an Order service interface
    def initialize(options = {})
      requires!(options, :username, :password)

      @username = options[:username]
      @password = options[:password]

      @options = options
    end

    # Public: Create a new order
    #
    # items - Array of hashes containing item_number and quantity
    # address - Hash of address
    # purchase_order - internal identifier for the order
    #
    # Returns an order_number
    def create_order(items, address, purchase_order_number, details = {})
      order = build_order_data
      order_items   = Array.new
      order[:order] = Hash.new
      shipping_information = Array.new

      items.each do |item|
        order_items.push(item: [
          { key: 'itemNumber', value: item[:item_number] },
          { key: 'quantity', value: item[:quantity] },
          { key: 'allowBackOrder', value: false, attributes!: { value: {'xsi:type' => 'xsd:boolean'} }}
        ])
      end

      shipping_information.push(*[
        { key: 'shipDate', value: Time.now.strftime("%Y-%m-%d") },
        { key: 'shipViaCode', value: 'UG' },
        { key: 'purchaseOrderNumber', value: purchase_order_number }
      ])

      if address[:fflno].present?
        ship_to_number = Zanders::Address.ship_to_number(address, @options)

        if ship_to_number[:success]
          shipping_information.push({key: 'shipToNo', value: ship_to_number[:ship_to_number] })
        else
          return { success: false, error_code: ship_to_number[:error_code] }
        end
      else
        shipping_information.push(*[
          { key: 'shipToAddress1',  value: address[:address1] },
          { key: 'shipToAddress2',  value: address[:address2] },
          { key: 'shipToCity',      value: address[:city]     },
          { key: 'shipToState',     value: address[:state]    },
          { key: 'shipToZip',       value: address[:zip]      }
        ])
      end

      if details[:name]
        shipping_information.push(
          { key: 'shipInstructions', value: format_shipping_instructions(details[:name], details[:phone_number]) }
        )
      end

      order[:order][:item] = shipping_information

      # NOTE-david
      # order(ns2 map)
      #   item
      #     key
      #     value(ns2map)
      #       item  - order item
      #       item  - order item
      #   item
      #     "
      #
      order_items = {item: order_items, attributes!: { item: { "xsi:type" => "ns2:Map"}, value: {"SOAP-ENC:arrayType" => "ns2:Map[2]", "xsi:type" => "SOAP-ENV:Array"} }}

      order[:order][:item].push({
        key: 'items',
        value: order_items
      })

      response = soap_client(ORDER_API_URL).call(:create_order, message: order)
      response = response.body[:create_order_response][:return][:item]

      if response.first[:value] == "0"
        { success: true, order_number: response.last[:value] }
      else
        { success: false, error_code: response.first[:value] }
      end
    end

    # Public: Get order info
    #
    # order_number - The String order number
    #
    # Returns Hash containing order information, or an error
    # code if the call failed
    def get_order(order_number)
      order = build_order_data.merge({ ordernumber: order_number })

      response = soap_client(ORDER_API_URL).call(:get_order_info, message: order)
      response = response.body[:get_order_info_response][:return][:item]

      # Successful call return_code is 0
      if response.first[:value] == "0"
        info = Hash.new

        # Just use the order number we already have
        info[:order_number] = order_number

        # Transform the response into a ruby-ish hash
        response.each do |part|
          case part[:key]
          when "purchaseOrderNumber"
            info[:purchase_order_number] = part[:value]
          when "orderDate"
            info[:order_date] = part[:value]
          when "orderEnteredDate"
            info[:ordered_entered_date] = part[:value]
          when "orderShipDate"
            info[:order_ship_date] = part[:value]
          when "subtotal"
            info[:subtotal] = part[:value]
          when "freight"
            info[:freight] = part[:value]
          when "miscFee"
            info[:misc_fee] = part[:value]
          when "selectionCode"
            info[:selection_code] = part[:value]
          when "datePicked"
            info[:date_picked] = part[:value]
          when "grandTotal"
            info[:grand_total] = part[:value]
          end
        end

        info[:success] = true

        info
      else
        { success: false, error_code: response.first[:value] }
      end
    end

    def get_tracking_info(order_number)
      order = build_order_data.merge({ ordernumber: order_number })

      response = soap_client(ORDER_API_URL).call(:get_tracking_info, message: order)
      response = response.body[:get_tracking_info_response][:return][:item]

      if response.first[:value] == "0"
        info = Hash.new

        if response.find { |i| i[:key] == "numberOfShipments" }[:value] != "0"
          tracking_numbers = response.find { |i| i[:key] == "trackingNumbers" }[:value]

          tracking_numbers[:item][:item].each do |part|
            case part[:key]
            when 'shipCompany'
              info[:company] = part[:value]
            when 'shipVia'
              info[:via] = part[:value]
            when 'trackingNumber'
              info[:tracking_number] = part[:value]
            when 'weight'
              info[:weight] = part[:value]
            when 'url'
              info[:url] = part[:value]
            end
          end

          info[:success] = true

          info
        else
          { success: false, error_code: response.first[:value], error_message: "No present tracking information" }
        end
      else
        { success: false, error_code: response.first[:value] }
      end
    end

    private

    # Private: Builds request data
    #
    # Returns Hash of username, password, and cast assignments
    def build_order_data
      hash = {
        :attributes! => {
          order: { "xsi:type" => "ns2:Map" }
        },
        username: @username,
        password: @password
        #testing: true
      }

      hash
    end

    # Private: Formats the name and phone number into a
    # string that is 80 characters long, with the first
    # 40 being the name, and the last being the phone
    # number. (This is the required format from Zanders
    #
    # name - A String of the name
    # phone_number - A string containing the phone number
    #
    # Returns a String(80) of the name and phone number
    def format_shipping_instructions(name, phone_number)
      shipping_instructions = "%-40.40s" % name
      shipping_instructions += phone_number
    end

  end
end