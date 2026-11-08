import tkinter as tk
from tkinter import messagebox

from game_logic import create_board, is_valid_move, make_move, check_winner, is_draw


class TicTacToeUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Jenkins Demo — Tic-Tac-Toe")
        self.board = create_board()
        self.current_player = "X"
        self.buttons = []

        for i in range(9):
            btn = tk.Button(
                root, text="", font=("Arial", 32), width=4, height=2,
                command=lambda i=i: self.handle_click(i),
            )
            btn.grid(row=i // 3, column=i % 3)
            self.buttons.append(btn)

        self.status = tk.Label(root, text=f"Player {self.current_player}'s turn", font=("Arial", 14))
        self.status.grid(row=3, column=0, columnspan=3, pady=10)

        tk.Button(root, text="Reset", command=self.reset).grid(row=4, column=0, columnspan=3, pady=5)

    def handle_click(self, position):
        if not is_valid_move(self.board, position):
            return

        self.board = make_move(self.board, position, self.current_player)
        self.buttons[position].config(text=self.current_player)

        winner = check_winner(self.board)
        if winner:
            messagebox.showinfo("Game Over", f"Player {winner} wins!")
            self.reset()
            return
        if is_draw(self.board):
            messagebox.showinfo("Game Over", "It's a draw!")
            self.reset()
            return

        self.current_player = "O" if self.current_player == "X" else "X"
        self.status.config(text=f"Player {self.current_player}'s turn")

    def reset(self):
        self.board = create_board()
        self.current_player = "X"
        for btn in self.buttons:
            btn.config(text="")
        self.status.config(text=f"Player {self.current_player}'s turn")


if __name__ == "__main__":
    root = tk.Tk()
    TicTacToeUI(root)
    root.mainloop()
