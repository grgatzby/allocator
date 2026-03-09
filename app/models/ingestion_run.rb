class IngestionRun < ApplicationRecord
  belongs_to :data_source

  STATUSES = %w[running success failed].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true
end
