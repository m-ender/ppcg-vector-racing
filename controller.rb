# Run like
# ruby controller.rb benchmarkfilename command to run racer
# e.g.
# ruby controller.rb benchmark.txt ruby randomracer.rb

# Patch a method into IO for more convenient nonblocking IO.
# Found at http://stackoverflow.com/a/948077/1633117
class IO
  def ready_for_read?
    result = IO.select([self], nil, nil, 0)
    result && (result.first.first == self)
  end
end

benchmark_file = ARGV.shift
racer_command = ARGV

tracks = File.open(benchmark_file).read.split("\n\n")

total_score = 0

tracks.map do |input|
    track = input.lines
    track.each(&:chomp!)

    target = track.shift.to_i
    size = track.shift.split.map(&:to_i)

    start_y = track.find_index { |row| row['S'] }
    start_x = track[start_y].index 'S'

    last_position = position = [start_x, start_y]

    turns = 0
    error = reached_goal = hit_wall = out_of_bounds = timed_out = false

    # Give one second per turn
    time_left = target

    racer = IO.popen(racer_command, 'r+')

    racer.puts input
    racer.each do |line|
        if !line[/^\s*[+-]?[01]\s+[+-]?[01]\s*$/]
            puts "Invalid move: #{line}"
            error = true
            break
        end

        turns += 1
        $stderr.puts "Racer says: #{line}"

        move = line.split.map(&:to_i)

        velocity = [position[0] - last_position[0],
                    position[1] - last_position[1]]

        velocity[0] += move[0]
        velocity[1] += move[1]

        last_position = position
        position = [last_position[0] + velocity[0],
                    last_position[1] + velocity[1]]

        if position[0] < 0 || position[0] >= size[0] ||
           position[1] < 0 || position[1] >= size[1]
            out_of_bounds = true
        else
            case track[position[1]][position[0]]
            when '#'
                hit_wall = true
            when '*'
                reached_goal = true
            end
        end

        break if timed_out ||
                 out_of_bounds ||
                 hit_wall ||
                 reached_goal ||
                 turns >= target

        racer.puts "Racer says: #{line}"
    end

    racer.close

    score = reached_goal ? turns/target.to_f : 2
    total_score += score

    if reached_goal
        puts "SCORE: #{score}. Racer reached goal at #{position} in #{turns} turns."
    elsif error
        puts "SCORE: #{score}. Racer produced error."
    elsif out_of_bounds
        puts "SCORE: #{score}. Racer went out of bounds at position #{position}."
    elsif hit_wall
        puts "SCORE: #{score}. Racer hit a wall at position #{position}."
    elsif turns >= target
        puts "SCORE: #{score}. Racer did not reach the goal within #{target} turns."
    else
        puts "SCORE: #{score}. Racer stopped before reaching goal."
    end
end

puts "TOTAL SCORE: #{total_score}"