import pytest

from game_logic import (
    create_board,
    is_valid_move,
    make_move,
    check_winner,
    is_draw,
    is_game_over,
)


def test_create_board_is_empty():
    board = create_board()
    assert len(board) == 9
    assert all(cell == "" for cell in board)


def test_valid_move_on_empty_cell():
    board = create_board()
    assert is_valid_move(board, 0) is True


def test_invalid_move_on_occupied_cell():
    board = make_move(create_board(), 0, "X")
    assert is_valid_move(board, 0) is False


def test_make_move_places_symbol():
    board = make_move(create_board(), 4, "X")
    assert board[4] == "X"


def test_make_move_raises_on_occupied_cell():
    board = make_move(create_board(), 0, "X")
    with pytest.raises(ValueError):
        make_move(board, 0, "O")


def test_check_winner_row():
    board = ["X", "X", "X", "", "", "", "", "", ""]
    assert check_winner(board) == "X"


def test_check_winner_column():
    board = ["O", "", "", "O", "", "", "O", "", ""]
    assert check_winner(board) == "O"


def test_check_winner_diagonal():
    board = ["X", "", "", "", "X", "", "", "", "X"]
    assert check_winner(board) == "X"


def test_no_winner_on_empty_board():
    assert check_winner(create_board()) is None


def test_draw_detection():
    board = ["X", "O", "X", "X", "O", "O", "O", "X", "X"]
    assert is_draw(board) is True
    assert check_winner(board) is None


def test_is_game_over_true_on_win():
    board = ["X", "X", "X", "", "", "", "", "", ""]
    assert is_game_over(board) is True


def test_is_game_over_false_mid_game():
    board = ["X", "O", "", "", "", "", "", "", ""]
    assert is_game_over(board) is False
