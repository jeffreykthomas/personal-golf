class SelfUnderstandingReportsController < ApplicationController
  def show
    @report = current_user.latest_self_understanding_report
  end
end
