require 'httparty'
require 'titleize'

class RepresentPostalCodeConcordance

  attr_accessor :response

  def self.find_by_postal_code(postal_code)
    new(postal_code)
  end

  def initialize(postal_code)
    self.response = HTTParty.get("http://represent.opennorth.ca/postcodes/#{postal_code}")
  end

  def not_found?
    response.response.code == "404"
  end

  def ontario_ridings
    @ontario_ridings ||= begin
      ridings = response_boundaries.find_all do |boundary|
        boundary['related']['boundary_set_url'] == "/boundary-sets/ontario-electoral-districts/"
      end
      ridings.map do |riding|
        {name: riding['name'], id: riding['external_id']}
      end
    end
  end

  def wards
    @wards ||= begin
      wards = response_boundaries.find_all do |boundary|
        boundary['related']['boundary_set_url'].include? 'ward'
      end
      wards.map do |ward|
        {name: ward['name'], id: ward['external_id'], ward_type: ward['boundary_set_name']}
      end
    end
  end

  def province
    format_province_str(response["province"])
  end

  def city
    format_city_str(response["city"])
  end

  def latitude
    response["centroid"]["coordinates"][0]
  end

  def longitude
    response["centroid"]["coordinates"][1]
  end

private

  def response_boundaries
    response["boundaries_centroid"] | response["boundaries_concordance"]
  end

  def format_city_str(str)
    str.strip.downcase.titleize
  end

  def format_province_str(str)
    str.strip.upcase
  end
end