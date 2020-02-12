require 'redis'
redis = Redis.new(url: ENV['REDIS'])
exit(1) if redis.get("sick-worker-#{ENV['WORKER_INDEX']}").any?