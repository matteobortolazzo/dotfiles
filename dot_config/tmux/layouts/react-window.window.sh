# create new window
new_window "react"
run_cmd "nvim ."

# split and run app
split_v 6
run_cmd "yarn && yarn dev"
split_h 50

# select first panel and zoom
select_pane 1
tmux resize-pane -Z
