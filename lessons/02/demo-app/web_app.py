from flask import Flask, jsonify, request

from game_logic import create_board, is_valid_move, make_move, check_winner, is_draw

app = Flask(__name__)

board = create_board()
current_player = "X"

PAGE = """
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Jenkins Demo — Tic-Tac-Toe</title>
<style>
  body { font-family: sans-serif; text-align: center; margin-top: 40px; background: #1e1e2e; color: #eee; }
  h1 { font-weight: 600; }
  table { margin: 0 auto; border-collapse: collapse; }
  td {
    width: 90px; height: 90px; border: 2px solid #555;
    font-size: 42px; text-align: center; cursor: pointer; user-select: none;
  }
  td:hover { background: #2a2a3d; }
  #status { font-size: 20px; margin-top: 20px; }
  button {
    margin-top: 15px; padding: 10px 20px; font-size: 16px;
    cursor: pointer; border: none; border-radius: 6px; background: #4f6df5; color: white;
  }
</style>
</head>
<body>
  <h1>Tic-Tac-Toe</h1>
  <table id="board"></table>
  <div id="status"></div>
  <button onclick="reset()">Reset</button>

<script>
async function render() {
  const res = await fetch('/state');
  const data = await res.json();
  const table = document.getElementById('board');
  table.innerHTML = '';
  for (let r = 0; r < 3; r++) {
    const row = document.createElement('tr');
    for (let c = 0; c < 3; c++) {
      const i = r * 3 + c;
      const cell = document.createElement('td');
      cell.textContent = data.board[i];
      cell.onclick = () => move(i);
      row.appendChild(cell);
    }
    table.appendChild(row);
  }
  document.getElementById('status').textContent = data.status;
}

async function move(i) {
  await fetch('/move', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({position: i})
  });
  render();
}

async function reset() {
  await fetch('/reset', {method: 'POST'});
  render();
}

render();
</script>
</body>
</html>
"""


@app.route("/")
def index():
    return PAGE


@app.route("/state")
def state():
    winner = check_winner(board)
    if winner:
        status = f"Player {winner} wins!"
    elif is_draw(board):
        status = "It's a draw!"
    else:
        status = f"Player {current_player}'s turn"
    return jsonify(board=board, status=status)


@app.route("/move", methods=["POST"])
def move():
    global board, current_player
    position = request.json["position"]
    if is_valid_move(board, position) and not check_winner(board) and not is_draw(board):
        board = make_move(board, position, current_player)
        if not check_winner(board) and not is_draw(board):
            current_player = "O" if current_player == "X" else "X"
    return jsonify(ok=True)


@app.route("/reset", methods=["POST"])
def reset():
    global board, current_player
    board = create_board()
    current_player = "X"
    return jsonify(ok=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
