session_root "~/Repos/actumfit"

if initialize_session "actumfit"; then
 
  window_root "~/Repos/actumfit/src/api/ActumFit/ActumFit.Api"
  load_window "dotnet-window"

  window_root "~/Repos/actumfit/src/ui/actumfit-chat"
  load_window "react-window"
  
  window_root "~/Repos/actumfit/src/ui/actumfit-business"
  load_window "react-window"
  
  new_window "utils"
  select_window 1

fi

finalize_and_go_to_session
