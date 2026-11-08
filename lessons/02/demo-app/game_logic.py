EMPTY = ""

WIN_LINES = [
    (0, 1, 2), (3, 4, 5), (6, 7, 8),  # rows
    (0, 3, 6), (1, 4, 7), (2, 5, 8),  # columns
    (0, 4, 8), (2, 4, 6),             # diagonals
]


def create_board():
    return [EMPTY] * 9


def is_valid_move(board, position):
    return 0 <= position <= 8 and board[position] == EMPTY


def make_move(board, position, player):
    if not is_valid_move(board, position):
        raise ValueError(f"Invalid move: position {position}")
    new_board = board.copy()
    new_board[position] = player
    return new_board


def check_winner(board):
    for a, b, c in WIN_LINES:
        if board[a] != EMPTY and board[a] == board[b] == board[c]:
            return board[a]
    return None


def is_draw(board):
    return EMPTY not in board and check_winner(board) is None


def is_game_over(board):
    return check_winner(board) is not None or is_draw(board)
