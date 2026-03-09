require "bigdecimal"

module Ingestion
  class WorldBankClient
    def initialize(http_client: nil)
      base_url = DataSource.find_by!(code: "world_bank").base_url
      @http_client = http_client || HttpClient.new(base_url: base_url)
    end

    def fetch_gdp_growth(country_iso3:, start_date: nil)
      fetch_indicator(
        country_iso3: country_iso3,
        indicator_code: SourceMappings::WORLD_BANK_GDP.fetch(:indicator_code),
        frequency: SourceMappings::WORLD_BANK_GDP.fetch(:frequency),
        start_date: start_date
      )
    end

    def fetch_inflation(country_iso3:, start_date: nil)
      fetch_indicator(
        country_iso3: country_iso3,
        indicator_code: SourceMappings::WORLD_BANK_INFLATION.fetch(:indicator_code),
        frequency: SourceMappings::WORLD_BANK_INFLATION.fetch(:frequency),
        start_date: start_date
      )
    end

    private

    def fetch_indicator(country_iso3:, indicator_code:, frequency:, start_date:)
      path = "/v2/country/#{country_iso3}/indicator/#{indicator_code}"
      params = { format: "json", per_page: 20_000 }
      params[:date] = "#{start_date.year}:#{Date.current.year}" if start_date.present?

      payload = @http_client.get_json(path: path, params: params)
      observations = parse_observations(payload, frequency: frequency)

      {
        source_series_key: "wb:#{indicator_code}:#{country_iso3}",
        indicator_code: indicator_code,
        country_iso3: country_iso3,
        frequency: frequency,
        observations: observations
      }
    end

    def parse_observations(payload, frequency:)
      rows = payload.is_a?(Array) ? payload.last : []
      return [] unless rows.is_a?(Array)

      rows.filter_map do |row|
        year = row["date"].to_i
        value = row["value"]
        next if year.zero? || value.nil?

        {
          period_date: normalized_period(year, frequency),
          value: BigDecimal(value.to_s),
          source_updated_at: parse_datetime(row["lastupdated"]),
          raw_payload: row
        }
      end
    end

    def normalized_period(year, frequency)
      case frequency
      when "A" then Date.new(year, 12, 31)
      else Date.new(year, 12, 31)
      end
    end

    def parse_datetime(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
