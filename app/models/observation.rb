class Observation < ApplicationRecord
  belongs_to :series

  validates :period_date, :value, :ingested_at, presence: true
end
