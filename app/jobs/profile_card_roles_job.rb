class ProfileCardRolesJob < ApplicationJob
  queue_as :background

  def perform(oracle_ids: nil)
    CardAnalysis::BatchProfiler.call(oracle_ids: oracle_ids)
  end
end
