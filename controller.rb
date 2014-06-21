# Run like
# ruby controller.rb benchmarkfilename command to run racer
# e.g.
# ruby controller.rb benchmark.txt ruby randomracer.rb

require 'timeout'

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
    velocity = [0,0]

    turns = 0
    error = reached_goal = hit_wall = out_of_bounds = timed_out = false

    # Give half a second per turn
    time_per_turn = 0.5
    time_budget = time_per_turn * target

    racer = IO.popen(racer_command, 'r+')

    racer.puts input
    racer.puts time_budget
    racer.flush

    last_time = Time.now

    begin
        Timeout::timeout(2*time_budget) do
            racer.each do |line|
                current_time = Time.now
                extra_time = current_time - last_time - time_per_turn
                last_time = current_time

                time_budget -= extra_time if extra_time > 0
                timed_out = time_budget <= 0

                if !line[/^\s*[+-]?[01]\s+[+-]?[01]\s*$/]
                    puts "Invalid move: #{line}"
                    error = true
                    break
                end

                turns += 1
                $stderr.puts "Racer says: #{line}"

                move = line.split.map(&:to_i)

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

                if timed_out ||
                   out_of_bounds ||
                   hit_wall ||
                   reached_goal ||
                   racer.closed? ||
                   turns >= target
                    racer.puts
                    racer.flush
                    break
                else
                    racer.puts position.join(' ')
                    racer.puts velocity.join(' ')
                    racer.puts time_budget
                    racer.flush
                end
            end
        end
    rescue Timeout::Error => e
        timed_out = true

        # Kill the process manually, otherwise we might have to
        # wait for it to finish before closing.
        Process.kill('KILL', racer.pid)
    rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
        error = true
    end

    racer.close

    score = reached_goal ? turns/target.to_f : 2
    total_score += score

    print 'SCORE: %1.5f ' % score
    if reached_goal
        puts "Racer reached goal at #{position} in #{turns} turns."
    elsif error
        puts "Racer produced error."
    elsif out_of_bounds
        puts "Racer went out of bounds at position #{position}."
    elsif hit_wall
        puts "Racer hit a wall at position #{position}."
    elsif timed_out
        puts "Racer timed out after #{turns} turns."
    elsif turns >= target
        puts "Racer did not reach the goal within #{target} turns."
    else
        puts "Racer stopped before reaching goal."
    end
end

puts 'TOTAL SCORE: %1.5f' % total_score