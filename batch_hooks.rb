require 'parallel_cucumber/dsl'
require 'json'


ParallelCucumber::DSL.after_batch do |outcome, _batch_id, env|
  scenario, result = outcome.first
  next if result[:status] == :passed
  next if ran_twice?(scenario)
  next if failed_with_business_reason?(result)

  mark_worker_as_sick(env['WORKER_INDEX'])
  requeue(scenario)
end


def ran_twice?(scenario)
  redis.get('rerun').include?(scenario)
end

def failed_with_business_reason?(details)
  details[:exception_classname] == "BusinessError"
end

def redis
  @redis ||= Redis.new(url: ENV['REDIS'])
end

def requeue(scenario)
  puts "=#=#=#=#=#=#=#=# Requeue #{scenario} =#=#=#=#=#=#=#=#"
  redis.lpush('rerun', scenario)
  redis.rpush('tests', scenario)
end

def mark_worker_as_sick(worker_index)
  redis.lpush("sick-worker-#{worker_index}", "Killed in After Batch")
end