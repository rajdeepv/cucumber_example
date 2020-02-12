require 'parallel_cucumber/dsl'
require 'json'

ParallelCucumber::DSL.after_batch do |results, batch_id, env, scenario_details|
  redis = Redis.new(url: ENV['REDIS'])
  not_passed_scenarios = results.reject { |_key, val| val == :passed }.keys
  not_passed_scenarios.map(&:to_s).each do |scenario|
    if redis.get('rerun').include?(scenario)
      next
    end
    details = JSON.parse(redis.rpop(batch_id))
    if details[scenario]["exception_class"] == "BusinessError"
      next
    end
    puts "=#=#=#=#=#=#=#=# Requeue #{scenario}, Reason: #{details[scenario]['exception_class']} =#=#=#=#=#=#=#=#"
    redis.lpush("kill-worker-#{ENV['WORKER_INDEX']}","Killed in After Batch")
    puts "=#=#=#=#=#=#=#=# Kill #{ENV['WORKER_INDEX']}, } =#=#=#=#=#=#=#=#"
    redis.lpush('rerun', scenario)
    redis.rpush('skanky', scenario)
  end
end

#ParallelCucumber::DSL.after_workers do
#  `killall -9 node`
#end