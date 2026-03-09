require "test_helper"

module Ingestion
  class EurostatClientTest < ActiveSupport::TestCase
    setup do
      DataSource.create!(code: "eurostat", name: "Eurostat", base_url: "https://ec.europa.eu/eurostat")
    end

    test "parses Eurostat JSON-stat payload" do
      payload = {
        "value" => { "0" => 2.1, "1" => 2.4 },
        "dimension" => {
          "time" => {
            "category" => {
              "label" => { "0" => "2024-01", "1" => "2024-02" }
            }
          }
        }
      }
      fake_http = Minitest::Mock.new
      fake_http.expect(:get_json, payload, [Hash])

      client = EurostatClient.new(http_client: fake_http)
      result = client.fetch_series(source_series_key: "irt_st_m", country_iso3: "FRA", frequency: "M")

      assert_equal "eu:irt_st_m:FRA", result[:source_series_key]
      assert_equal 2, result[:observations].size
      assert_equal Date.new(2024, 2, 29), result[:observations][1][:period_date]
      assert_equal BigDecimal("2.4"), result[:observations][1][:value]
      fake_http.verify
    end
  end
end
