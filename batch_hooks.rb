require 'parallel_cucumber/dsl'
require 'json'

ParallelCucumber::DSL.after_batch do |results, batch_id, env|
  not_passed_scenarios = results.reject {|_key, val| val[:status] == :passed}.keys.map(&:to_s)
  not_passed_scenarios.each do |scenario|

    next if ran_twice?(scenario)

    next if failed_with_business_reason?(scenario, batch_id)

    mark_worker_as_sick(env['WORKER_INDEX'])
    requeue(scenario)
  end
end

#ParallelCucumber::DSL.after_workers do
#  `killall -9 node`
#end

def ran_twice?(scenario)
  redis.get('rerun').include?(scenario)
end

def failed_with_business_reason?(scenario, batch_id)
  details = JSON.parse(redis.rpop(batch_id))
  details[scenario]["exception_class"] == "BusinessError"
end

def redis
  @redis ||= Redis.new(url: ENV['REDIS'])
end

def requeue(scenario)
  puts "=#=#=#=#=#=#=#=# Requeue #{scenario} =#=#=#=#=#=#=#=#"
  redis.lpush('rerun', scenario)
  redis.rpush('skanky', scenario)
end

def mark_worker_as_sick(worker_index)
  redis.lpush("sick-worker-#{worker_index}", "Killed in After Batch")
end