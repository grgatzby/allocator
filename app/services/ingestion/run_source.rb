require "json"
require "fileutils"

module Ingestion
  class RunSource
    LOG_DIR = Rails.root.join("log", "ingestion_runs").freeze
    KNOWN_DATA_SOURCES = {
      "world_bank" => { name: "World Bank", base_url: "https://api.worldbank.org" },
      "imf" => { name: "IMF SDMX", base_url: "https://dataservices.imf.org/REST/SDMX_JSON.svc" },
      "eurostat" => { name: "Eurostat", base_url: "https://ec.europa.eu/eurostat" },
      "oecd" => { name: "OECD SDMX", base_url: "https://sdmx.oecd.org/public/rest" }
    }.freeze

    def self.call(data_source_code:, raise_on_error: true)
      new(data_source_code: data_source_code).call(raise_on_error: raise_on_error)
    end

    def self.log_file_path_for(run_id)
      LOG_DIR.join("run_#{run_id}.json")
    end

    def initialize(data_source_code:)
      @data_source = find_or_bootstrap_data_source!(data_source_code)
    end

    def call(raise_on_error: true)
      run = @data_source.ingestion_runs.create!(
        status: "running",
        started_at: Time.current
      )

      rows_read = 0
      rows_written = 0
      payload_summaries = []

      each_payload do |payload|
        observations = payload.fetch(:observations, [])
        result = ImportSeries.call(
          data_source_code: @data_source.code,
          indicator_code: payload.fetch(:indicator_code),
          country_iso3: payload[:country_iso3],
          source_series_key: payload.fetch(:source_series_key),
          frequency: payload.fetch(:frequency),
          observations: observations
        )
        read_count = result.fetch(:rows_read)
        written_count = result.fetch(:rows_written)
        missing_count = [read_count - written_count, 0].max

        rows_read += read_count
        rows_written += written_count
        payload_summaries << build_payload_summary(payload, read_count, written_count, missing_count)
      end

      run.update!(
        status: "success",
        finished_at: Time.current,
        rows_read: rows_read,
        rows_written: rows_written
      )
      write_run_log(run: run, payload_summaries: payload_summaries, error_message: nil)
      run
    rescue StandardError => e
      run&.update!(
        status: "failed",
        finished_at: Time.current,
        rows_read: rows_read || 0,
        rows_written: rows_written || 0,
        error_message: e.message
      )
      write_run_log(run: run, payload_summaries: payload_summaries || [], error_message: e.message) if run.present?
      raise if raise_on_error

      nil
    end

    private

    def find_or_bootstrap_data_source!(data_source_code)
      data_source = DataSource.find_by(code: data_source_code)
      return data_source if data_source.present?

      defaults = KNOWN_DATA_SOURCES[data_source_code]
      raise ActiveRecord::RecordNotFound, "Unknown data source code: #{data_source_code}" if defaults.nil?

      DataSource.create!(code: data_source_code, **defaults)
    end

    def each_payload
      case @data_source.code
      when "world_bank"
        (world_bank_payloads + world_bank_inflation_payloads + fx_payloads_for(SourceMappings::G20_ISO3, "world_bank")).each { |payload| yield payload }
      when "imf"
        (imf_payloads + imf_inflation_payloads + fx_payloads_for(SourceMappings::G20_ISO3, "imf")).each { |payload| yield payload }
      when "eurostat"
        (eurostat_payloads + eurostat_inflation_payloads + fx_payloads_for(SourceMappings::EU_G20_ISO3, "eurostat")).each { |payload| yield payload }
      when "oecd"
        oecd_payloads.each { |payload| yield payload }
      else
        raise ArgumentError, "Unsupported data source: #{@data_source.code}"
      end
    end

    def world_bank_payloads
      client = WorldBankClient.new

      SourceMappings::G20_ISO3.map do |iso3|
        payload = client.fetch_gdp_growth(country_iso3: iso3, start_date: next_start_date("world_bank", "wb:NY.GDP.MKTP.KD.ZG:#{iso3}"))
        payload.merge(indicator_code: SourceMappings::WORLD_BANK_GDP.fetch(:indicator_code))
      end
    end

    def world_bank_inflation_payloads
      client = WorldBankClient.new

      SourceMappings::G20_ISO3.map do |iso3|
        series_key = "wb:#{SourceMappings::WORLD_BANK_INFLATION.fetch(:indicator_code)}:#{iso3}"
        payload = client.fetch_inflation(
          country_iso3: iso3,
          start_date: next_start_date("world_bank", series_key)
        )
        payload.merge(indicator_code: SourceMappings::WORLD_BANK_INFLATION.fetch(:indicator_code))
      end
    end

    def imf_payloads
      client = ImfClient.new

      SourceMappings::IMF_SERIES.flat_map do |series_map|
        if series_map.fetch(:country_dependent)
          SourceMappings::G20_ISO3.map do |iso3|
            build_imf_payload(client, series_map, iso3)
          end
        else
          [build_imf_payload(client, series_map, nil)]
        end
      end
    end

    def build_imf_payload(client, series_map, country_iso3)
      series_key = "imf:#{series_map.fetch(:source_series_key)}:#{country_iso3 || 'GLOBAL'}"
      payload = if series_map[:source_series_keys].present?
                  client.fetch_first_available_series(
                    source_series_keys: series_map.fetch(:source_series_keys),
                    canonical_series_key: series_map.fetch(:source_series_key),
                    country_iso3: country_iso3,
                    start_date: next_start_date("imf", series_key),
                    frequency: series_map.fetch(:frequency)
                  )
                else
                  client.fetch_series(
                    source_series_key: series_map.fetch(:source_series_key),
                    country_iso3: country_iso3,
                    start_date: next_start_date("imf", series_key),
                    frequency: series_map.fetch(:frequency)
                  )
                end
      payload.merge(indicator_code: series_map.fetch(:indicator_code))
    end

    def oecd_payloads
      client = OecdSdmxClient.new

      SourceMappings::OECD_RATE_SERIES.flat_map do |series_map|
        SourceMappings::G20_ISO3.map do |iso3|
          series_key = "oecd:#{series_map.fetch(:source_series_key)}:#{iso3}"
          payload = client.fetch_financial_market_rate(
            country_iso3: iso3,
            measure_codes: series_map.fetch(:measure_codes),
            source_series_key: series_key,
            start_date: next_start_date("oecd", series_key),
            frequency: series_map.fetch(:frequency)
          )
          payload.merge(indicator_code: series_map.fetch(:indicator_code))
        end
      end
    end

    def eurostat_payloads
      client = EurostatClient.new

      SourceMappings::EUROSTAT_SERIES.flat_map do |series_map|
        SourceMappings::EUROSTAT_GEO_CODES.map do |geo_code|
          country = Country.find_by(iso2: geo_code)
          next if country.nil?

          short_code = series_map.dig(:query_params, :int_rt)&.downcase
          series_suffix = short_code.present? ? ":#{short_code}" : ""
          series_key = "eu:#{series_map.fetch(:source_series_key)}:#{country.iso3}#{series_suffix}"
          payload = client.fetch_series(
            source_series_key: series_map.fetch(:source_series_key),
            country_iso3: geo_code,
            start_date: next_start_date("eurostat", series_key),
            frequency: series_map.fetch(:frequency),
            query_params: series_map.fetch(:query_params, {})
          )
          payload.merge(
            indicator_code: series_map.fetch(:indicator_code),
            country_iso3: country.iso3,
            source_series_key: series_key
          )
        end.compact
      end
    end

    def imf_inflation_payloads
      client = ImfClient.new

      SourceMappings::NON_EU_G20_ISO3.map do |iso3|
        series_key = "imf:cpi_yoy:#{iso3}"
        payload = client.fetch_cpi_yoy(
          country_iso3: iso3,
          start_date: next_start_date("imf", series_key)
        )
        payload.merge(
          indicator_code: SourceMappings::IMF_INFLATION.fetch(:indicator_code),
          source_series_key: series_key
        )
      end
    end

    def eurostat_inflation_payloads
      client = EurostatClient.new

      SourceMappings::EUROSTAT_GEO_TO_ISO3.map do |geo_code, iso3|
        series_key = "eu:hicp_yoy:#{iso3}"
        payload = client.fetch_hicp_yoy(
          country_geo_code: geo_code,
          start_date: next_start_date("eurostat", series_key)
        )
        payload.merge(
          indicator_code: SourceMappings::EUROSTAT_HICP.fetch(:indicator_code),
          country_iso3: iso3,
          source_series_key: series_key
        )
      end
    end

    def fx_payloads_for(country_iso3_list, source_code)
      client = FxUsdClient.new

      country_iso3_list.filter_map do |iso3|
        currency_code = SourceMappings::COUNTRY_CURRENCIES[iso3]
        next if currency_code.blank?

        series_key = "fx:usd:#{iso3}"
        payload = client.fetch_monthly_fx(
          country_iso3: iso3,
          currency_code: currency_code,
          start_date: next_start_date(source_code, series_key)
        )
        payload.merge(indicator_code: SourceMappings::FX_INDICATOR.fetch(:indicator_code))
      end
    end

    def next_start_date(data_source_code, source_series_key)
      data_source = DataSource.find_by(code: data_source_code)
      return unless data_source

      series = Series.find_by(data_source: data_source, source_series_key: source_series_key)
      return unless series

      series.observations.maximum(:period_date)&.+(1.day)
    end

    def write_run_log(run:, payload_summaries:, error_message:)
      FileUtils.mkdir_p(LOG_DIR)

      missing_series = payload_summaries.select { |p| p[:observations_received].zero? || p[:missing_observations].positive? }
      extracted_series = payload_summaries.select { |p| p[:observations_written].positive? }

      payload = {
        run: {
          id: run.id,
          source: run.data_source.code,
          status: run.status,
          started_at: run.started_at,
          finished_at: run.finished_at,
          rows_read: run.rows_read,
          rows_written: run.rows_written,
          error_message: error_message
        },
        summary: {
          extracted_series_count: extracted_series.size,
          missing_series_count: missing_series.size
        },
        extracted_data: extracted_series,
        missing_data: missing_series
      }

      File.write(self.class.log_file_path_for(run.id), JSON.pretty_generate(payload))
    end

    def build_payload_summary(payload, read_count, written_count, missing_count)
      {
        source_series_key: payload.fetch(:source_series_key),
        indicator_code: payload.fetch(:indicator_code),
        country_iso3: payload[:country_iso3],
        frequency: payload.fetch(:frequency),
        observations_received: read_count,
        observations_written: written_count,
        missing_observations: missing_count
      }
    end
  end
end
