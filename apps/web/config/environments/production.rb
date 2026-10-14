require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.secret_key_base = ENV["SECRET_KEY_BASE"] || "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0123456789"

  # Container standard: log to STDOUT
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue

  config.active_support.report_deprecations = false
end
