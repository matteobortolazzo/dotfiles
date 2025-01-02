session_root "~/Repos/actumfit"

if initialize_session "actumfit"; then
 
  window_root "~/Repos/actumfit/src/api/ActumFit/ActumFit.Api"
  new_window "api"
  split_v 25
  select_pane 1
  run_cmd "nvim ."

  window_root "~/Repos/actumfit/src/ui/actumfit-business/"
  new_window "business"
  split_v 25
  select_pane 1
  run_cmd "nvim ."
  
  new_window "git"
  run_cmd "lazygit"

  select_window 1

fi

finalize_and_go_to_session
