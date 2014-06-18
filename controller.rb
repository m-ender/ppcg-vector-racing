# Run like
# ruby controller.rb benchmarkfilename command to run racer
# e.g.
# ruby .\controller.rb .\benchmark.txt ruby .\randomracer.rb

benchmark_file = ARGV.shift
racer_command = ARGV

tracks = File.open(benchmark_file).read.split("\n\n")

tracks.map do |input|
    track = input.lines
    track.each(&:chomp!)

    target = track.shift.to_i
    size = track.shift.split.map(&:to_i)

    start_y = track.find_index { |row| row['S'] }
    start_x = track[start_y].index 'S'

    position = [start_x, start_y]

    racer = IO.popen(racer_command, 'r+')

    racer.puts input
    racer.each do |line|
        $stderr.puts 'Racer says: '+line
        racer.puts 'Racer says: '+line
    end

    racer.close
end