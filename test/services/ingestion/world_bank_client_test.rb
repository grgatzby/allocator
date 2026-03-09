require "test_helper"

module Ingestion
  class WorldBankClientTest < ActiveSupport::TestCase
    setup do
      DataSource.create!(code: "world_bank", name: "World Bank", base_url: "https://api.worldbank.org")
    end

    test "parses world bank payload to normalized observations" do
      payload = [
        { "page" => 1 },
        [
          { "date" => "2023", "value" => 1.2, "lastupdated" => "2024-01-10" },
          { "date" => "2022", "value" => nil, "lastupdated" => "2024-01-10" }
        ]
      ]
      fake_http = Minitest::Mock.new
      fake_http.expect(:get_json, payload, [Hash])

      client = WorldBankClient.new(http_client: fake_http)
      result = client.fetch_gdp_growth(country_iso3: "FRA")

      assert_equal "wb:NY.GDP.MKTP.KD.ZG:FRA", result[:source_series_key]
      assert_equal "NY.GDP.MKTP.KD.ZG", result[:indicator_code]
      assert_equal "A", result[:frequency]
      assert_equal 1, result[:observations].size
      assert_equal Date.new(2023, 12, 31), result[:observations].first[:period_date]
      assert_equal BigDecimal("1.2"), result[:observations].first[:value]
      fake_http.verify
    end
  end
end
