#!/usr/bin/env ruby

require "json"
require "net/http"
require "optparse"



def create_game(client)
  req = Net::HTTP::Post.new("/games", "Content-Type" => "application/json")
  res = client.request(req)

  JSON.parse(res.body)["id"]
end

def join_game(client, player_name, game_id, auto)
  req = Net::HTTP::Post.new("/games/#{game_id}/players",
                            "Content-Type" => "application/json")
  body = { name: player_name }
  if auto
    body[:pair] = 1
  end
  req.body = body.to_json

  JSON.parse(client.request(req).body)

end

def play(client, game_id, secret, board, cell)
  req = Net::HTTP::Post.new("/games/#{game_id}/moves",
                            "Content-Type" => "application/json",
                            "X-Token" => secret)
  req.body = { board: board, cell: cell }.to_json

  JSON.parse(client.request(req).body)
end

def print_board(game)
  printed_boards = game["boards"].map do |board|
    board["rows"].map do |row|
      row.map { |cell| cell || "-" }.join(" ")
    end
  end

  [0, 3, 6].each do |i|
    (0..2).each do |j|
      puts [printed_boards[i][j],
            printed_boards[i+1][j],
            printed_boards[i+2][j]].join("  ")
    end
    puts "\n"
  end
end

http_client = Net::HTTP.new("tictactoe.inseng.net", 80)
options = {}

OptionParser.new do |opts|
  opts.on("-p", "--player=PLAYER", "Player name") do |v|
    options[:player_name] = v
  end

  opts.on("-g", "--game=GAME", "Game id") do |v|
    options[:game] = v
  end

  opts.on("-a", "--auto", "if set, pair with a robot player") do |v|
    options[:auto] = v
  end
end.parse!

player_name = options[:player_name]
game_id     = options[:game] ? options[:game] : create_game(http_client)

game = join_game(http_client, player_name, game_id, options[:auto])
puts "Game starte: #{game}"
loop do
  print_board(game)
  break if game["state"] != "inProgress"

  next_board = game["nextBoard"]
  boards = game["boards"]

  # TODO: your logic here. you should assign values to `board` and `cell`
  if next_board
    board = boards[next_board]
    board_index = next_board
  else
    board_index = boards.find_index { |board| !!board["playable"] }
    board = boards[board_index]
  end
  puts "Board Index: #{board_index}"
  cells = board["rows"].flatten
  cell_grid = coerce_cells(cells, game["currentPlayer"])
  cell = cells.find_index { |index|
    !!index.nil? && winning_move?(cell_grid, index)
  }
  cell = preferred_cell_move(cells) if cell.nil?
  puts cell

  game = play(http_client, game["id"], game["currentPlayer"]["secret"], board_index, cell)
end

def winning_move?(grid, move)
  new_grid = grid.dup
  new_grid[move] = true
  win_conditions = [[0, 4, 8], [2, 4, 6], [0, 3, 6], [2, 5, 8], [0, 1, 2], [6, 7, 8], [1, 4, 7], [3, 4, 5]]
  valid_win_conditions = win_conditions.select { |row| row.include?(move) }
  valid_win_conditions.any? { |row|
    row.all?{ |index| new_grid[index] }
  }
end

def coerce_cells(cells, player)
  cells.flatten.map { |cell| cell == player["token"] }
end

def coerce_boards(boards, player)
  boards.map{ |board|
    winner = board["winner"]
    winner && winner["name"] == player
  }
end

def preferred_cell_move(cells)
  corners = [0, 2, 6, 8]
  middle = [4]
  sides = [1, 3, 5, 7]

  cells.find_index{ |index| index.nil? && corners.include?(index) } ||
  cells.find_index{ |index| index.nil? && middle.include?(index) } ||
  cells.find_index{ |index| index.nil? && sides.include?(index) }
end



puts "Game state: #{game["state"]}"
puts "Game winner: #{game["winner"] ? game["winner"]["name"] : "None"}"
