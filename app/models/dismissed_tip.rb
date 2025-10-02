class DismissedTip < ApplicationRecord
  belongs_to :user
  belongs_to :tip
end
