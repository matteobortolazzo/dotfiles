session_root "~/Repos/leaderboards/"

if initialize_session "leaderboards"; then
 
  window_root "~/Repos/leaderboards/src/leaderboards-api/"
  new_window "api"
  split_v 25
  select_pane 1
  run_cmd "nvim ."

  window_root "~/Repos/leaderboards/src/leaderboards-cli/"
  new_window "cli"
  split_v 25
  select_pane 1
  run_cmd "nvim ."

  window_root "~/Repos/leaderboards/src/leaderboards-app/"
  new_window "app"
  split_v 25
  select_pane 1
  run_cmd "nvim ."

  window_root "~/Repos/leaderboards/src/leaderboards-overlay/"
  new_window "overlay"
  split_v 25
  select_pane 1
  run_cmd "nvim ."


  new_window "git"
  run_cmd "lazygit"

  select_window 1

fi

finalize_and_go_to_session
