#!/bin/bash

active_workspace_id=$(hyprctl activeworkspace -j | jq '.id')
clients_to_kill=$(\
      hyprctl clients -j | \
      jq ".[] | select(.workspace.id==${active_workspace_id}) " | \
      jq ".pid"
 )
kill $(echo $clients_to_kill)
