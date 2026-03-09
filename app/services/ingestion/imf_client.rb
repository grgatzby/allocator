require "bigdecimal"

module Ingestion
  class ImfClient
    def initialize(http_client: nil)
      base_url = DataSource.find_by!(code: "imf").base_url
      @http_client = http_client || HttpClient.new(base_url: base_url)
    end

    def fetch_series(source_series_key:, country_iso3: nil, start_date: nil, frequency: "M")
      path = "/CompactData/IFS/#{build_query(source_series_key, country_iso3)}"
      params = {}
      params[:startPeriod] = start_date.strftime("%Y-%m") if start_date.present?

      payload = @http_client.get_json(path: path, params: params)
      {
        source_series_key: source_series_key_for(source_series_key, country_iso3),
        country_iso3: country_iso3,
        frequency: frequency,
        observations: parse_observations(payload, frequency: frequency)
      }
    end

    def fetch_first_available_series(source_series_keys:, canonical_series_key:, country_iso3:, start_date: nil, frequency: "M")
      source_series_keys.each do |candidate_key|
        payload = fetch_series(
          source_series_key: candidate_key,
          country_iso3: country_iso3,
          start_date: start_date,
          frequency: frequency
        )
        observations = payload.fetch(:observations, [])
        next if observations.empty?

        return {
          source_series_key: source_series_key_for(canonical_series_key, country_iso3),
          country_iso3: country_iso3,
          frequency: frequency,
          observations: observations.map do |obs|
            obs.merge(raw_payload: obs[:raw_payload].merge("matched_series_code" => candidate_key))
          end
        }
      end

      {
        source_series_key: source_series_key_for(canonical_series_key, country_iso3),
        country_iso3: country_iso3,
        frequency: frequency,
        observations: []
      }
    end

    def fetch_cpi_yoy(country_iso3:, start_date: nil)
      fetch_start = start_date.present? ? (start_date << 12) : nil
      index_payload = fetch_series(
        source_series_key: SourceMappings::IMF_INFLATION.fetch(:source_series_key),
        country_iso3: country_iso3,
        start_date: fetch_start,
        frequency: "M"
      )
      observations = compute_yoy_from_index(index_payload.fetch(:observations), start_date: start_date)

      {
        source_series_key: "imf:cpi_yoy:#{country_iso3}",
        country_iso3: country_iso3,
        frequency: "M",
        observations: observations
      }
    end

    private

    def build_query(source_series_key, country_iso3)
      country = country_iso3.presence || "W00"
      "#{frequency_code_for(source_series_key)}.#{country}.#{source_series_key}"
    end

    def source_series_key_for(source_series_key, country_iso3)
      country_iso3.present? ? "imf:#{source_series_key}:#{country_iso3}" : "imf:#{source_series_key}:GLOBAL"
    end

    def parse_observations(payload, frequency:)
      observations = extract_obs(payload)
      observations.filter_map do |obs|
        period = obs["@TIME_PERIOD"] || obs["TIME_PERIOD"]
        value = obs["@OBS_VALUE"] || obs["OBS_VALUE"]
        next if period.blank? || value.blank?
        period_date = normalize_period(period, frequency)
        next if period_date.nil?

        {
          period_date: period_date,
          value: BigDecimal(value.to_s),
          raw_payload: obs
        }
      end
    end

    def extract_obs(payload)
      data_set = payload.dig("CompactData", "DataSet")
      series = data_set.is_a?(Hash) ? data_set["Series"] : nil
      series = series.first if series.is_a?(Array)
      obs = series.is_a?(Hash) ? series["Obs"] : []
      obs.is_a?(Array) ? obs : Array(obs).compact
    end

    def normalize_period(period, frequency)
      case frequency
      when "A"
        Date.new(period.to_i, 12, 31)
      when "Q"
        year, quarter = period.split("-Q")
        month = quarter.to_i * 3
        Date.new(year.to_i, month, -1)
      else
        Date.parse("#{period}-01").end_of_month
      end
    rescue Date::Error
      nil
    end

    def frequency_code_for(source_series_key)
      case source_series_key
      when "short_rate", "long_rate", "gold_usd_oz", "wti_usd_bbl", "PCPI_IX", "FIDR_PA", "FIMM_PA", "FIGB_PA", "FILR_PA", "PGOLD_USD", "POILWTI_USD"
        "M"
      else
        "M"
      end
    end

    def compute_yoy_from_index(index_observations, start_date:)
      sorted = index_observations.sort_by { |obs| obs[:period_date] }
      by_date = sorted.to_h { |obs| [obs[:period_date], obs] }

      sorted.filter_map do |obs|
        current_date = obs[:period_date]
        previous_date = current_date << 12
        previous = by_date[previous_date]
        next if previous.nil?
        next if previous[:value].to_d.zero?
        next if start_date.present? && current_date < start_date

        yoy = ((obs[:value].to_d / previous[:value].to_d) - 1) * 100
        {
          period_date: current_date,
          value: yoy.round(6),
          raw_payload: {
            derived_from: "PCPI_IX",
            current: obs[:raw_payload],
            previous: previous[:raw_payload]
          }
        }
      end
    end
  end
end
