# Parse initial input
target = gets.to_i
size = gets.split.map(&:to_i)
track = []
size[1].times do
    track.push gets
end
time_budget = gets.to_f

# Find start position
start_y = track.find_index { |row| row['S'] }
start_x = track[start_y].index 'S'

position = [start_x, start_y]
velocity = [0, 0]

while true
    x = rand(3) - 1
    y = rand(3) - 1
    puts [x,y].join ' '
    $stdout.flush

    first_line = gets
    break if !first_line || first_line.chomp.empty?

    position = first_line.split.map(&:to_i)
    velocity = gets.split.map(&:to_i)
    time_budget = gets.to_f
end