require "test_helper"

module Ingestion
  class ImportSeriesTest < ActiveSupport::TestCase
    setup do
      @data_source = DataSource.create!(code: "world_bank", name: "World Bank", base_url: "https://api.worldbank.org")
      @indicator = Indicator.create!(code: "NY.GDP.MKTP.KD.ZG", name: "GDP growth", category: "gdp", unit: "%", default_frequency: "A")
      @country = Country.create!(name: "France", iso2: "FR", iso3: "FRA", region: "Europe")
    end

    test "upserts without duplicates and preserves created_at" do
      ImportSeries.call(
        data_source_code: "world_bank",
        indicator_code: "NY.GDP.MKTP.KD.ZG",
        country_iso3: "FRA",
        source_series_key: "wb:NY.GDP.MKTP.KD.ZG:FRA",
        frequency: "A",
        observations: [{ period_date: Date.new(2023, 12, 31), value: 1.0 }]
      )

      observation = Observation.first
      first_created_at = observation.created_at

      ImportSeries.call(
        data_source_code: "world_bank",
        indicator_code: "NY.GDP.MKTP.KD.ZG",
        country_iso3: "FRA",
        source_series_key: "wb:NY.GDP.MKTP.KD.ZG:FRA",
        frequency: "A",
        observations: [{ period_date: Date.new(2023, 12, 31), value: 2.0 }]
      )

      assert_equal 1, Observation.count
      assert_equal BigDecimal("2.0"), Observation.first.value
      assert_equal first_created_at, Observation.first.created_at
    end

    test "rejects conflicting metadata for existing series" do
      ImportSeries.call(
        data_source_code: "world_bank",
        indicator_code: "NY.GDP.MKTP.KD.ZG",
        country_iso3: "FRA",
        source_series_key: "wb:NY.GDP.MKTP.KD.ZG:FRA",
        frequency: "A",
        observations: [{ period_date: Date.new(2022, 12, 31), value: 1.0 }]
      )

      assert_raises(ArgumentError) do
        ImportSeries.call(
          data_source_code: "world_bank",
          indicator_code: "NY.GDP.MKTP.KD.ZG",
          country_iso3: "FRA",
          source_series_key: "wb:NY.GDP.MKTP.KD.ZG:FRA",
          frequency: "M",
          observations: [{ period_date: Date.new(2023, 1, 31), value: 1.1 }]
        )
      end
    end

    test "skips invalid observations" do
      result = ImportSeries.call(
        data_source_code: "world_bank",
        indicator_code: "NY.GDP.MKTP.KD.ZG",
        country_iso3: "FRA",
        source_series_key: "wb:NY.GDP.MKTP.KD.ZG:FRA",
        frequency: "A",
        observations: [
          { period_date: Date.new(2020, 12, 31), value: 0.5 },
          { period_date: nil, value: 0.3 },
          { period_date: Date.new(2021, 12, 31), value: nil }
        ]
      )

      assert_equal 3, result[:rows_read]
      assert_equal 1, result[:rows_written]
      assert_equal 1, Observation.count
    end
  end
end
