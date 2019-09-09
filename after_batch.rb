require 'parallel_cucumber/dsl'

ParallelCucumber::DSL.after_batch do |results, batch_id, env, scenario_details|
  redis = Redis.new(url: ENV['REDIS'])
  not_passed_scenarios = results.reject { |_key, val| val == :passed }.keys
  not_passed_scenarios.map(&:to_s).each do |scenario|
    if redis.get('rerun').include?(scenario)
      next
    end
    puts "^^^^^ Requeue #{scenario}"
    redis.lpush('rerun', scenario)
    redis.rpush('skanky', scenario)
  end
end
