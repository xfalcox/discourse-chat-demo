# frozen_string_literal: true

module ::ChatDemo
  class Message < ActiveRecord::Base
    self.table_name = "chat_demo_messages"

    scope :unsent, -> { where(sent_at: nil).order(:id) }

    # Atomically claim the next unsent line for posting. `FOR UPDATE SKIP LOCKED`
    # lets the per-minute fan-out jobs run concurrently while guaranteeing no two
    # workers ever grab the same line. Returns the claimed record (already stamped
    # as sent) or nil when the script is fully posted.
    def self.claim_next!
      transaction do
        row = unsent.lock("FOR UPDATE SKIP LOCKED").first

        next nil if row.nil?

        row.update!(sent_at: Time.zone.now)
        row
      end
    end

    # Replay the whole script from the top. Called by the single-concurrency
    # dispatcher when no unsent lines remain, so the channel never goes quiet
    # between daily refreshes.
    def self.replay!
      unscoped.update_all(sent_at: nil)
    end
  end
end
