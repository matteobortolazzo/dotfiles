# create new window
new_window "dotnet"
run_cmd "nvim ."

# split and restore packages
split_v 6 
run_cmd "dotnet restore && dotnet watch build"
split_h 50

# select first panel and zoom
select_pane 1
tmux resize-pane -Z
