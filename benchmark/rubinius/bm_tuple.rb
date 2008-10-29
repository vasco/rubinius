require 'benchmark'
 
total = (ENV['TOTAL'] || 5_000).to_i

Benchmark.bmbm do |x|
  x.report 'empty' do
    total.times {|i| Tuple.new(1) }
  end

  x.report 'Tuple#initialize' do
    total.times do |i|
      Tuple.new(i)
    end
  end

  x.report 'Tuple#+' do
    total.times do |i|
      Tuple.new(i) + Tuple.new(i)
    end
  end
end
