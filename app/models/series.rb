class Series < ApplicationRecord
  belongs_to :data_source
  belongs_to :indicator
  belongs_to :country, optional: true
  has_many :observations, dependent: :delete_all

  validates :source_series_key, :frequency, presence: true
end
