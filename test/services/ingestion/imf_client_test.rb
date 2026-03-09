require "test_helper"

module Ingestion
  class ImfClientTest < ActiveSupport::TestCase
    setup do
      DataSource.create!(code: "imf", name: "IMF", base_url: "https://dataservices.imf.org/REST/SDMX_JSON.svc")
    end

    test "parses IMF compact data payload" do
      payload = {
        "CompactData" => {
          "DataSet" => {
            "Series" => {
              "Obs" => [
                { "@TIME_PERIOD" => "2024-01", "@OBS_VALUE" => "4.10" },
                { "@TIME_PERIOD" => "2024-02", "@OBS_VALUE" => "4.25" }
              ]
            }
          }
        }
      }
      fake_http = Minitest::Mock.new
      fake_http.expect(:get_json, payload, [Hash])

      client = ImfClient.new(http_client: fake_http)
      result = client.fetch_series(source_series_key: "short_rate", country_iso3: "FRA", frequency: "M")

      assert_equal "imf:short_rate:FRA", result[:source_series_key]
      assert_equal "FRA", result[:country_iso3]
      assert_equal 2, result[:observations].size
      assert_equal Date.new(2024, 1, 31), result[:observations][0][:period_date]
      assert_equal BigDecimal("4.10"), result[:observations][0][:value]
      fake_http.verify
    end
  end
end
