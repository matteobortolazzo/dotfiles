session_root "~/Repos/leaderboards/"

if initialize_session "leaderboards"; then
 
  window_root "~/Repos/leaderboards/src/leaderboards-api/"
  new_window "api"
  split_h 25
  select_pane 1
  run_cmd "nvim ."
  tmux resize-pane -Z

  window_root "~/Repos/leaderboards/src/leaderboards-cli/"
  new_window "cli"
  split_h 25
  select_pane 1
  run_cmd "nvim ."
  tmux resize-pane -Z

  window_root "~/Repos/leaderboards/src/leaderboards-app/"
  new_window "app"
  split_h 25
  select_pane 1
  run_cmd "nvim ."
  tmux resize-pane -Z

  window_root "~/Repos/leaderboards/src/leaderboards-overlay/"
  new_window "overlay"
  split_h 25
  select_pane 1
  run_cmd "nvim ."
  tmux resize-pane -Z

  new_window "git"
  run_cmd "lazygit"

  select_window 1

fi

finalize_and_go_to_session
