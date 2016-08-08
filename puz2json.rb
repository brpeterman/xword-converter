# Convert a PUZ file to the JSON format that the NY TImes Crossword app likes
# PUZ file specification from:
#  https://code.google.com/archive/p/puz/wikis/FileFormat.wiki

require 'json'

module XWordConverter
  class Puzzle
    attr_accessor :width, :height, :clues, :cells, :across_clues, :down_clues, :author, :copyright, :title

    def initialize()
      @across_clues = {}
      @down_clues = {}
    end

    def parse_puz(input_file)
      puz_data = IO.binread input_file
      parser = PuzParser.new puz_data, self
    end

    def to_json()
      puzzle_json = {}
      puzzle_json["PackId"] = nil
      puzzle_json["authors"] = [@author.force_encoding("ISO-8859-1")]
      puzzle_json["created"] = nil
      puzzle_json["day_of_week"] = nil
      puzzle_json["enhanced_tier_date"] = nil
      puzzle_json["format_type"] = nil
      puzzle_json["last_modified"] = nil
      puzzle_json["next_puzzle_in_streak"] = false
      puzzle_json["percentageComplete"] = 0
      puzzle_json["print_date"] = "" # TODO: Send a real date
      puzzle_json["publish_type"] = nil
      puzzle_json["published"] = nil
      puzzle_json["puzzle_id"] = "" # TODO: Send a puzzle ID
      puzzle_json["puzzle_meta"] = {
        "author": @author.force_encoding("ISO-8859-1"),
        "copyright": @copyright.force_encoding("ISO-8859-1"),
        "editor": "",
        "formatType": "Normal",
        "height": @height,
        "layoutExtra": [],
        "links": [],
        "notes": [],
        "printDate": "", # TODO: Send real date
        "printDotw": "", # TODO: Send real day of day of week
        "publishType": "Daily",
        "title": @title.force_encoding("ISO-8859-1"),
        "width": @width
      }
      puzzle_json["puzzle_type"] = 1
      puzzle_json["status"] = nil
      puzzle_json["tags"] = nil
      puzzle_json["version"] = 2
      puzzle_json["weekly_free_date"] = nil
      puzzle_json["puzzle_data"] = {
        "answers": @cells
      }
      puzzle_json["clues"] = {}
      puzzle_json["clues"]["A"] = []
      @across_clues.each_value do |clue|
        puzzle_json["clues"]["A"] << clue
      end
      puzzle_json["clues"]["D"] = []
      @down_clues.each_value do |clue|
        puzzle_json["clues"]["D"] << clue
      end

      puzzle_json.to_json
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
      cells = layout_data.bytes.pack("c*").chars
      @puzzle.cells = cells.map {|cell| cell != '.' ? cell : nil }
      $stderr.puts "Cells: #{cells}"
    end

    def parse_strings(strings_data)
      strings = strings_data.split("\000")
      @puzzle.title = strings[0]
      @puzzle.author = strings[1]
      @puzzle.copyright = strings[2]

      $stderr.puts "Title: #{@puzzle.title}"
      $stderr.puts "Author: #{@puzzle.author}"
      $stderr.puts "Copyright: #{@puzzle.copyright}"

      clues = strings.slice(3..@num_clues+3).map {|text| text.force_encoding("ISO-8859-1")}
      create_clues(clues)

      $stderr.puts "Across:"
      @puzzle.across_clues.each do |number, clue|
        $stderr.puts "#{number}: #{clue.text} (#{clue.length} letters)"
      end

      $stderr.puts "\nDown:"
      @puzzle.down_clues.each do |number, clue|
        $stderr.puts "#{number}: #{clue.text} (#{clue.length} letters)"
      end
    end

    def create_clues(clues)
      cell_number = 1

      (0..@puzzle.height-1).each do |y|
        (0..@puzzle.width-1).each do |x|
          if @puzzle.cells[cell_index(x, y)] == nil
            next
          end

          assigned_number = false
          length = across_cell(x, y)
          if length
            @puzzle.across_clues[cell_number] = Clue.new(cell_number, clues.shift, length, cell_index(x, y), cell_index(x+length-1, y))
            assigned_number = true
          end
          length = down_cell(x, y)
          if length
            @puzzle.down_clues[cell_number] = Clue.new(cell_number, clues.shift, length, cell_index(x, y), cell_index(x, y+(length*(@puzzle.width-1))))
            assigned_number = true
          end
          if assigned_number
            cell_number += 1
          end
        end
      end
    end

    def across_cell(x, y)
      if x == 0 || @puzzle.cells[cell_index(x-1, y)] == nil
        if x + 1 < @puzzle.width && @puzzle.cells[cell_index(x+1, y)] != nil
          across_clue_length(x, y)
        end
      end
    end

    def across_clue_length(x, y)
      length = 0
      (x..@puzzle.width-1).each do |position|
        if @puzzle.cells[cell_index(position, y)] == nil
          break
        end
        length += 1
      end
      length
    end

    def down_cell(x, y)
      if y == 0 || @puzzle.cells[cell_index(x, y-1)] == nil
        if y + 1 < @puzzle.height && @puzzle.cells[cell_index(x, y+1)] != nil
          down_clue_length(x, y)
        end
      end
    end

    def down_clue_length(x, y)
      length = 0
      (y..@puzzle.height-1).each do |position|
        if @puzzle.cells[cell_index(x, position)] == nil
          break
        end
        length += 1
      end
      length
    end

    def cell_index(x, y)
      y * @puzzle.width + x
    end
  end

  class Clue
    attr_reader :number, :text, :length, :start, :end

    def initialize(number, text, length, start_cell, end_cell)
      @number = number
      @text = text
      @length = length
      @start = start_cell
      @end = end_cell
    end

    def to_json(not_used)
      {
        "value": @text,
        "clueStart": @start,
        "clueEnd": @end,
        "formatted": nil,
        "related": nil,
        "clueNum": @number
      }.to_json
    end
  end

  class FormatException < Exception
  end
end

if __FILE__ == $0
  puzzle = XWordConverter::Puzzle.new
  puzzle.parse_puz("examples/Jul3116.puz")
  puzzle_json = puzzle.to_json
  File.open("test_output.json", "w") do |file|
    file.puts puzzle_json
  end
end
