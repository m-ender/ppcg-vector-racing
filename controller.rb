# Run like
# ruby controller.rb benchmarkfilename command to run racer
# e.g.
# ruby controller.rb benchmark.txt ruby randomracer.rb
# For more detailed output, you can add "-v" before the benchmark
# file name.

require 'optparse'
require 'timeout'

require_relative 'lib/point2d'
require_relative 'lib/track'

verbose = false
silent = false
selected_tracks = nil
OptionParser.new do |opts|
    opts.banner = "Usage: #$0 [options] benchmark_file [racer]"

    opts.on("-v", "Verbose") { verbose = true }
    opts.on("-s", "Silent") { silent = true }
    opts.on("-t TRACKS", "Select tracks") { |t| selected_tracks = eval("[#{t}]").map{|el|el.respond_to?(:to_a) ? el.to_a : el}.flatten }
end.parse!

benchmark_file = ARGV.shift

if ARGV.length > 0
    # Pretend we've read this from commands.txt as the only command
    racers = [ARGV]
    racers[0].unshift '1'
    racers[0].unshift(silent ? '1' : '0')
    racers[0].unshift ''
else
    racers = File.open('submissions/commands.txt').read.split("\n").map(&:split)
end

tracks = File.open(benchmark_file).read.split("\n\n")
selected_tracks ||= (1..tracks.size)

results = {}

racers.each do |racer|
    average_score = 0

    author = racer.shift
    next if author[0] == '#'
    silent = (racer.shift == '1')
    n_runs = racer.shift.to_i
    racer_command = racer

    puts
    puts "Racer by #{author}" if author != ''
    puts "Running '#{racer_command.join ' '}' against #{benchmark_file}"
    puts

    n_runs.times do
        total_score = 0

        puts ' No.       Size     Target   Score     Details'
        puts '-'*85

        selected_tracks.each do |idx|
            input = tracks[idx - 1]

            if verbose
                puts
                puts "Starting track no. #{idx}. Track data:"
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
                            if silent
                                Process.kill('KILL', racer.pid)
                            else
                                racer.puts
                                racer.flush
                            end
                            break
                        elsif !silent
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

            print "% 3d   %6d x %-3d   % 5d   %7.5f   " % [idx, track.size.x, track.size.y, track.target, score]
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

        average_score += total_score/n_runs

        puts '-'*85
        puts 'TOTAL SCORE: % 23.5f' % total_score
        puts
    end

    results[author] = average_score
end

if racers.length > 1
    puts '          Score Board'
    puts '  ============================'
    puts
    puts '   User                 Score'
    puts '  ----------------------------'
    results.each { |k,v| puts '  %-18s %9.5f' % [k, v] }
    puts
end
