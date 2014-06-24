# Run like
# ruby controller.rb benchmarkfilename command to run racer
# e.g.
# ruby controller.rb benchmark.txt ruby randomracer.rb
# For more detailed output, you can add "-v" before the benchmark
# file name.

$:.push File.expand_path(File.dirname(__FILE__) + '/lib')

require 'timeout'

require 'point2d'
require 'track'

first_arg = ARGV.shift
verbose = (first_arg == '-v')

benchmark_file = verbose ? ARGV.shift : first_arg

racer_command = ARGV

tracks = File.open(benchmark_file).read.split("\n\n")

total_score = 0

puts
puts "Running '#{racer_command.join ' '}' against #{benchmark_file}"
puts
puts ' No.    Size     Target   Score     Details'
puts '-'*85

track_num = 0
tracks.map do |input|
    track_num += 1

    if verbose
        puts
        puts "Starting track no. #{track_num}. Track data:"
        puts
        puts input
        puts
    end

    track = Track.new(input)

    # Give half a second per turn
    time_per_turn = 0.5
    time_budget = time_per_turn * track.target

    last_position = position = track.start
    velocity = Point2D.new(0, 0)

    turns = 0
    reached_goal = false
    failure = :none

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
                failure = :timed_out if time_budget <= 0

                if !line[/^\s*[+-]?[01]\s+[+-]?[01]\s*$/]
                    $stderr.puts "Invalid move: #{line}"
                    failure = :error
                    break
                end

                turns += 1
                puts "Racer says: #{line}" if verbose

                move = Point2D.from_string line

                velocity += move

                last_position = position
                position = last_position + velocity

                case track.get position
                when :out_of_bounds
                    failure = :out_of_bounds
                when :wall
                    failure = :hit_wall
                when :goal
                    reached_goal = true
                end

                failure = :exceeded_target if turns >= track.target

                if reached_goal ||
                   failure != :none ||
                   racer.closed?
                    racer.puts
                    racer.flush
                    break
                else
                    racer.puts position
                    racer.puts velocity
                    racer.puts time_budget
                    racer.flush
                end
            end
        end
    rescue Timeout::Error => e
        failure = :timed_out

        # Kill the process manually, otherwise we might have to
        # wait for it to finish before closing.
        Process.kill('KILL', racer.pid)
    rescue Exception => e
        $stderr.puts e.message
        $stderr.puts e.backtrace.inspect
        failure = :error
    end

    racer.close

    score = reached_goal ? turns/track.target.to_f : 2
    total_score += score

    if verbose
        puts
        puts 'Result:'
    end

    print "% 3d   %3d x %-3d   % 5d   %7.5f   " % [track_num, track.size.x, track.size.y, track.target, score]
    if reached_goal
        puts "Racer reached goal at #{position.pretty} in #{turns} turns."
    else
        case failure
        when :error
            puts "Racer produced error."
        when :out_of_bounds
            puts "Racer went out of bounds at position #{position.pretty}."
        when :hit_wall
            puts "Racer hit a wall at position #{position.pretty}."
        when :timed_out
            puts "Racer timed out after #{turns} turns."
        when :exceeded_target
            puts "Racer did not reach the goal within #{track.target} turns."
        else
            puts "Racer stopped before reaching goal."
        end
    end
end

puts '-'*85
puts 'TOTAL SCORE: % 20.5f' % total_score
puts