class Series < ApplicationRecord
  belongs_to :data_source
  belongs_to :indicator
  belongs_to :country
end
