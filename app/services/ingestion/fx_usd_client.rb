require "bigdecimal"
require "set"

module Ingestion
  class FxUsdClient
    DEFAULT_START_DATE = Date.new(2000, 1, 1)

    def initialize(http_client: nil)
      @http_client = http_client || HttpClient.new(base_url: "https://api.frankfurter.app/")
    end

    def fetch_monthly_fx(country_iso3:, currency_code:, start_date: nil)
      effective_start = [start_date || DEFAULT_START_DATE, DEFAULT_START_DATE].max
      end_date = Date.current

      observations = if currency_code == "USD"
                       build_usd_observations(effective_start, end_date)
                     elsif !supported_currency?(currency_code)
                       []
                     else
                       payload = @http_client.get_json(
                         path: "#{effective_start}..#{end_date}",
                         params: { from: currency_code, to: "USD" }
                       )
                       parse_monthly_observations(payload)
                     end

      {
        source_series_key: "fx:usd:#{country_iso3}",
        country_iso3: country_iso3,
        frequency: "M",
        observations: observations
      }
    rescue StandardError => e
      return empty_payload(country_iso3) if e.message.start_with?("HTTP 404")

      raise
    end

    private

    def supported_currency?(currency_code)
      @supported_currencies ||= begin
        payload = @http_client.get_json(path: "currencies")
        payload.keys.to_set
      rescue StandardError
        Set.new
      end
      @supported_currencies.include?(currency_code)
    end

    def parse_monthly_observations(payload)
      rates = payload["rates"]
      return [] unless rates.is_a?(Hash)

      monthly = {}
      rates.each do |date_str, rate_payload|
        usd_rate = rate_payload["USD"]
        next if usd_rate.nil?

        date = Date.parse(date_str)
        key = date.strftime("%Y-%m")
        monthly[key] = { period_date: date.end_of_month, value: BigDecimal(usd_rate.to_s), raw_payload: { date: date_str, rate: usd_rate } }
      end

      monthly.values.sort_by { |obs| obs[:period_date] }
    end

    def build_usd_observations(start_date, end_date)
      current = Date.new(start_date.year, start_date.month, 1)
      last_month = Date.new(end_date.year, end_date.month, 1)
      observations = []

      while current <= last_month
        observations << {
          period_date: current.end_of_month,
          value: BigDecimal("1"),
          raw_payload: { date: current.end_of_month.to_s, rate: 1.0 }
        }
        current = current.next_month
      end

      observations
    end

    def empty_payload(country_iso3)
      {
        source_series_key: "fx:usd:#{country_iso3}",
        country_iso3: country_iso3,
        frequency: "M",
        observations: []
      }
    end
  end
end
