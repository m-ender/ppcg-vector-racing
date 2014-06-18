target = gets.to_i
size = gets.split.map(&:to_i)
track = []
size[1].times do
    track.push gets
end
x = rand(3) - 1
y = rand(3) - 1
puts [x,y].join ' '