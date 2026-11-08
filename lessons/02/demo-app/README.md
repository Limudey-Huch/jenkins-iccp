# demo-app — Tic-Tac-Toe

A tiny Tic-Tac-Toe game, split into three files on purpose:

- `game_logic.py` — pure game logic (board state, move validation, win/draw detection). No UI, no I/O. This is what the Jenkins pipeline tests.
- `game_ui.py` — a `tkinter` desktop window that lets you play locally on a machine with a display.
- `web_app.py` — a Flask web server exposing the same game in a browser. This is what the Docker image runs by default, so the game is reachable from any machine on the network (e.g. `http://<VM_IP>:5000`) — no display needed on the host.

## Why split like this?

A CI pipeline runs inside a Docker container with **no display** — it can't click buttons or render a window. By keeping all the game *rules* in a plain Python module with no UI dependency, `pytest` can fully test the logic (every win condition, invalid moves, draws) without ever touching a screen. Both UIs (`game_ui.py`, `web_app.py`) are thin, untested wrappers around logic that's already proven correct.

This mirrors a real-world pattern: keep business logic separate from UI so it's testable in CI.

## Run the tests (same thing Jenkins does)

```bash
pip install pytest
pytest --junitxml=results.xml
```

Only `test_game_logic.py` exists — there's nothing to test in either UI file, since neither has logic of its own.

## Play it locally (desktop window)

```bash
python3 game_ui.py
```

(`tkinter` ships with most Python installs. On some Linux distros you may need `sudo apt install python3-tk` first.)

## Play it in a browser, served from the VM

The Docker image's default command runs the Flask app (`CMD ["python", "web_app.py"]`). The Jenkinsfile's **Test** stage overrides that command to run `pytest` instead — so building and testing via the pipeline doesn't start the web server. To actually run the game after a pipeline build:

```bash
docker run -d -p 5000:5000 --name tictactoe myapp:<BUILD_NUMBER>
```

Then open `http://<VM_IP>:5000` from your Mac's browser. Stop it later with `docker rm -f tictactoe`.
