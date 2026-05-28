# frozen_string_literal: true

module ::Jobs
  module ChatDemo
    # Runs every minute and fans out single-message posting jobs spaced evenly
    # across the minute, so the channel gets a steady drip of activity without
    # blocking a Sidekiq worker on a long sleep.
    class DispatchMessages < ::Jobs::Scheduled
      every 1.minute
      cluster_concurrency 1

      def execute(_args)
        return unless SiteSetting.chat_demo_enabled
        return if SiteSetting.chat_demo_channel_id.to_i <= 0

        per_minute = SiteSetting.chat_demo_messages_per_minute
        return if per_minute <= 0

        # Replay from the top once the script is fully posted, so the channel
        # stays lively between daily refreshes. Kept in this single-concurrency
        # dispatcher to avoid racing resets across workers.
        ::ChatDemo::Message.replay! if ::ChatDemo::Message.unsent.empty?

        # Nothing generated yet (e.g. no LLM configured) — wait for the daily job.
        return if ::ChatDemo::Message.unsent.empty?

        spacing = 60.0 / per_minute
        per_minute.times do |i|
          delay = (i * spacing).round + rand(0..2)
          ::Jobs.enqueue_in(delay, ::Jobs::ChatDemo::PostMessage)
        end
      end
    end
  end
end
