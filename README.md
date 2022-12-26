# Real-debrid magnet mime-handler

A mime-handler for magnet links.

This script automatically submits magnet links to real-debrid.

## Installation

```
git clone https://github.com/libklein/rd-magnet-mime-handler/ "${XDG_DATA_HOME:-$HOME/.local/share}/real-debrid"
sed "s#QUEUE_MAGNET_SCRIPT_DIR#${XDG_DATA_HOME:-$HOME/.local/share}/real-debrid#" "${XDG_DATA_HOME:-$HOME/.local/share}/real-debrid/real-debrid-magnet.desktop" > ${XDG_DATA_HOME:-$HOME/.local/share}/applications/real-debrid-magnet.desktop
"${XDG_DATA_HOME:-$HOME/.local/share}/real-debrid/request_token.sh"
update-desktop-database
```

## Requirements

* `curl`
* `jq`
* `zenity` (optional)
