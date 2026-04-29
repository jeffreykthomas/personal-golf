class SelfUnderstandingReportsController < ApplicationController
  def show
    @report = current_user.latest_self_understanding_report
    @profile_inventory = NanoclawProfileInventoryClient.new(user: current_user).fetch
  end
end
