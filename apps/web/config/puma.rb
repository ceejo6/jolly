threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"
environment ENV.fetch("RAILS_ENV", "production")

plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"
