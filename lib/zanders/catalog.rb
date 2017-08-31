module Zanders
  class Catalog < Base

    CATALOG_FILENAME  = "zandersinv.csv"

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.all(chunk_size = 15, options = {}, &block)
      requires!(options, :username, :password)
      new(options).all(chunk_size, &block)
    end

    def all(chunk_size, &block)
      connect(@options) do |ftp|
        begin
          csv_tempfile = Tempfile.new

          ftp.chdir(Zanders.config.ftp_directory)
          ftp.getbinaryfile(CATALOG_FILENAME, csv_tempfile.path)

          SmarterCSV.process(csv_tempfile, {
            :chunk_size => chunk_size,
            :convert_values_to_numeric => false,
            :key_mapping => {
              :available    => :quantity,
              :desc1        => :short_description,
              :itemnumber   => :item_identifier,
              :manufacturer => :brand,
              :mfgpnumber   => :mfg_number,
              :mapprice     => :map_price,
              :price1       => :price
            }
          }) do |chunk|
            chunk.each do |item|
              item[:name] = item[:short_description]
              item[:long_description] = "#{item[:short_description]} #{item[:desc2]}"

              item.except!(:desc2, :qty1, :qty2, :qty3, :price2, :price3)
            end

            yield(chunk)
          end

          csv_tempfile.unlink
        ensure
          ftp.close
        end
      end
    end

  end
end
