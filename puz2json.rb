# Convert a PUZ file to the JSON format that the NY TImes Crossword app likes
# PUZ file specification from:
#  https://code.google.com/archive/p/puz/wikis/FileFormat.wiki

module XWordConverter
  class Puzzle
    attr_accessor :width, :height, :clues, :cells

    def initialize()

    end

    def parse_puz(input_file)
      puz_data = IO.binread input_file
      parser = PuzParser.new puz_data
    end

    def to_json()

    end
  end

  class PuzParser
    MAGIC_STRING = [0x4143, 0x524f, 0x5353, 0x2644, 0x4f57, 0x4e00].pack("nnnnnn")

    def initialize(puz_data, puzzle=nil)
      if !puzzle
        puzzle = Puzzle.new
      end

      @puzzle = puzzle
      parse puz_data
    end

    def parse(puz_data)
      header_data = puz_data.byteslice(0x0, 0x34)
      parse_header header_data

      layout_data = puz_data.byteslice(0x34, @puzzle.width * @puzzle.height)
      parse_layout layout_data

      strings_offset = 0x34 + (2 * @puzzle.width * @puzzle.height)
      strings_length = puz_data.bytesize - strings_offset
      strings_data = puz_data.byteslice(strings_offset, strings_length)
      parse_strings strings_data
    end

    def parse_header(header_data)
      @checksum = header_data.byteslice(0x0, 0x2).unpack("n").first
      $stderr.puts "Checksum: #{@checksum}"
      header_const = header_data.byteslice(0x2, 0xc)
      if header_const != MAGIC_STRING
        raise FormatException.new "Invalid header."
      end

      version = header_data.byteslice(0x18, 0x4)
      $stderr.puts "Version: #{version}"

      @puzzle.width = header_data.byteslice(0x2c, 0x1).unpack("c").first
      $stderr.puts "Width: #{@puzzle.width}"

      @puzzle.height = header_data.byteslice(0x2d, 0x1).unpack("c").first
      $stderr.puts "Height: #{@puzzle.height}"

      @num_clues = header_data.byteslice(0x2e, 0x2).unpack("v").first
      $stderr.puts "Num clues: #{@num_clues}"
    end

    def parse_layout(layout_data)
      cells = layout_data.bytes.pack("c*")
      @puzzle.cells = cells
      $stderr.puts "Cells: #{cells}"
    end

    def parse_strings(strings_data)
      strings = strings_data.split("\000")
      title = strings[0]
      author = strings[1]
      copyright = strings[2]

      $stderr.puts "Title: #{title}"
      $stderr.puts "Author: #{author}"
      $stderr.puts "Copyright: #{copyright}"

      strings.slice(3..@num_clues+3).each do |clue|
        $stderr.puts "#{clue}"
      end
    end
  end

  class FormatException < Exception
  end
end

if __FILE__ == $0
  puzzle = XWordConverter::Puzzle.new
  puzzle.parse_puz("examples/Jul3116.puz")
end
