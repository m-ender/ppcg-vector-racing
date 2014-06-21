class Track
    attr_accessor :target, :size, :start

    def initialize(string)
        @track = string.lines
        @track.each(&:chomp!)

        @target = @track.shift.to_i
        @size = Point2D.from_string @track.shift

        start_y = @track.find_index { |row| row['S'] }
        start_x = @track[start_y].index 'S'

        @start = Point2D.new(start_x, start_y)
    end

    def out_of_bounds(point)
        point.x < 0 || point.x >= @size.x || point.y < 0 || point.y >= @size.y
    end

    def get(point)
        if out_of_bounds point
            return :out_of_bounds
        end

        case @track[point.y][point.x]
        when '#'
            :wall
        when '*'
            :goal
        when '.', 'S'
            :road
        end
    end
end