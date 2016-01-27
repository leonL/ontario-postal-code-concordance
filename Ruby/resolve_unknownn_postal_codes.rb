require './lib/represent_postal_code_concordance.rb'
require 'csv'; CSV::Converters[:na_to_nil] = Proc.new {|val| val == "NA" ? nil : val}
require 'pry'

class ConcordanceWriter

  def self.run
    concord_writer = new
    concord_writer.fetch_data_and_write_csv
  end

  def initialize
    @riding_concordance = open_output_csv('man_sask_postal_code_ridings_concordance.csv')
    @failed_codes = open_output_csv('failed_postal_codes.csv')
    # @geo_concordance = open_output_csv('ontario_postal_code_geo_concordance.csv')
    # @ward_concordance = open_output_csv('ontario_postal_code_wards_concordance.csv')

    at_exit do
     close_csvs(@riding_concordance, @failed_codes)
     File.open('current_pcode_on_program_exit.txt', 'w'){ |f| f.write(@current_src_postal_code) } if @current_src_postal_code
    end
  end

  def fetch_data_and_write_csv
    source_postal_codes.each do |source_record|
      @current_src_postal_code = source_record[:postal_code]
      @current_province = source_record[:province].downcase
      concordance = fetch_data_for_postal_code(@current_src_postal_code)

      if concordance.not_found?
        puts "Something went wrong requesting the postal code #{@current_src_postal_code} from the Represent API."
        @failed_codes << [@current_src_postal_code, @current_province]
      else
        cache_concordance_values(@current_src_postal_code, concordance)
      end
    end
    @current_src_postal_code = nil
  end

private

  def fetch_data_for_postal_code(pcode)
    sleep(1) # stay within represent.opennorth.ca/api rate limit
    ::RepresentPostalCodeConcordance.find_by_postal_code(pcode)
  end

  def cache_concordance_values(pcode, concordance)
    ridings = concordance.provincial_ridings(@current_province)

    if ridings.empty?
      puts "The postal code #{@current_src_postal_code} doesn't have any ridings for #{@current_province} on the Represent API."
      @failed_codes << [@current_src_postal_code, @current_province]
    else
      ridings.each do |riding|
        insert_riding_csv_row(pcode, riding)
      end
    end

  end

  def insert_riding_csv_row(pcode, riding)
    row = [pcode, @current_province, riding[:name], riding[:id ]]
    @riding_concordance << row; log_insert(row, 'riding')
  end

  def insert_geo_csv_row(pcode, concord)
    row = [pcode, concord.latitude, concord.longitude, concord.city, concord.province]
    @geo_concordance << row; log_insert(row, 'geo')
  end

  def insert_ward_csv_row(pcode, ward)
    row = [pcode, ward[:id], ward[:name], ward[:ward_type]]
    @ward_concordance << row; log_insert(row, 'ward')
  end

  def log_insert(row, concordance_type)
    puts "Inserting... #{row} into #{concordance_type} concordance"
  end

  def source_postal_codes
    csv_params = {headers: true, header_converters: :symbol,
      converters: :na_to_nil}
    CSV.table(source_codes_path, csv_params)
  end

  def source_codes_path
    self.class.source_dir + 'man_sask_postal_codes.csv'
  end

  def open_output_csv(filename)
    CSV.open(
      self.class.output_dir + filename, 'a', {quote_char: '"', force_quotes: true}
    )
  end

  def self.output_dir
    '../data/output/'
  end

  def self.source_dir
    '../data/src/'
  end

  def close_csvs(*csvs)
    csvs.each &:close
  end
end

ConcordanceWriter.run