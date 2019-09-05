require 'parallel_cucumber/dsl'

ParallelCucumber::DSL.after_batch do |results, batch_id, env, scenario_details|
  require 'pry'; binding.pry
end
