# frozen_string_literal: true

module ::ChatDemo
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace ChatDemo
    config.autoload_paths << File.join(config.root, "lib")

    # Scheduled jobs are not eager loaded by default in dev; mirror the pattern
    # used by other plugins so `every`-based jobs register with Sidekiq.
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      if Dir.exist?(scheduled_job_dir)
        Rails.autoloaders.main.eager_load_dir(scheduled_job_dir)
      end
    end
  end
end
