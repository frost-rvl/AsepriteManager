#!/bin/bash

source ./scripts/install.sh
source ./scripts/uninstall.sh
ASEPRITE_DIR="/opt/aseprite"

#------------------------
# Menu functions
# -----------------------

get_latest_stable_version(){
    curl -s https://api.github.com/repos/aseprite/aseprite/releases | \
    grep -Po '"tag_name": "\K.*?(?=")' | \
    grep -v -i 'beta\|alpha\|rc' | \
    head -1
}

get_latest_stable_version_with_date(){
    local json=$(curl -s https://api.github.com/repos/aseprite/aseprite/releases)

    local tag=""
    local date=""

    while IFS= read -r line; do
        if echo "$line" | grep -q '"tag_name"'; then
            local current_tag=$(echo "$line" | grep -Po '"tag_name": "\K.*?(?=")')
            if ! echo "$current_tag" | grep -qi 'beta\|alpha\|rc'; then
                tag="$current_tag"
                date=$(echo "$json" | grep -A 50 "\"tag_name\": \"$tag\"" | grep -m1 -Po '"published_at": "\K.*?(?=")')
                break
            fi
        fi
    done <<< "$(echo "$json" | grep '"tag_name"')"

    echo "${tag}|${date}"
}

get_active_version_date(){
    local active="$1"
    if [ "$active" == "none" ] || [ -z "$active" ]; then
        echo "unknown"
        return
    fi

    local date=$(curl -s "https://api.github.com/repos/aseprite/aseprite/releases/tags/$active" | \
                 grep -Po '"published_at": "\K.*?(?=")')

    if [ -z "$date" ]; then
        echo "unknown"
    else
        echo "$date"
    fi
}

is_stable_version(){
    local version="$1"
    if echo "$version" | grep -qi 'beta\|alpha\|rc'; then
        return 1
    else
        return 0
    fi
}

get_active_version(){
    if [ -L "$ASEPRITE_DIR/active" ];then
        basename "$(readlink -f "$ASEPRITE_DIR/active")"
    else
        echo "none"
    fi
}

check_update(){
    local latest_info=$(get_latest_stable_version_with_date)
    local latest=$(echo "$latest_info" | cut -d'|' -f1)
    local latest_date=$(echo "$latest_info" | cut -d'|' -f2)
    local active=$(get_active_version)

    echo "Latest stable release: $latest"
    if [ "$latest_date" != "unknown" ] && [ -n "$latest_date" ]; then
        local formatted_date=$(echo "$latest_date" | sed 's/T/ /' | sed 's/Z.*//' | cut -d':' -f1,2)
        echo "┗━ Released: $formatted_date"
    fi

    echo "Active installed version: $active"
    if [ "$active" == "none" ]; then
        echo "********* NO VERSION INSTALLED *********"
        return
    fi

    if ! is_stable_version "$active"; then
        echo "┗━ Pre-release version"
        echo "You are using a pre-release version. Latest stable: $latest"
        return
    fi

    if [ "$latest" == "$active" ];then
        echo "You are using the latest stable version."
        return
    fi

    local active_date=$(get_active_version_date "$active")
    if [ "$active_date" != "unknown" ] && [ "$latest_date" != "unknown" ] && [ -n "$active_date" ] && [ -n "$latest_date" ]; then
        local formatted_active_date=$(echo "$active_date" | sed 's/T/ /' | sed 's/Z.*//' | cut -d':' -f1,2)
        echo "    Released: $formatted_date"

        local latest_clean=$(echo "$latest_date" | sed 's/T/ /' | sed 's/Z//')
        local active_clean=$(echo "$active_date" | sed 's/T/ /' | sed 's/Z//')
        local latest_timestamp=$(date -d "$latest_clean" +%s 2>/dev/null || echo 0)
        local active_timestamp=$(date -d "$active_clean" +%s 2>/dev/null || echo 0)
        if [ "$latest_timestamp" -gt "$active_timestamp" ]; then
            echo "********* UPDATE AVAILABLE ! *********"
        else
            echo "You are using a recent stable version."
        fi
    else
        if [ "$latest" != "$active" ];then
            echo "********* UPDATE AVAILABLE ! *********"
        fi
    fi
}

list_all_versions(){
    echo ""
    echo "===== Installed Versions ====="
    echo ""

    if [ ! -d "$ASEPRITE_DIR" ];then
        echo "No versions installed."
        return
    fi

    local active=$(get_active_version)
    local versions=$(ls -1 "$ASEPRITE_DIR" | grep -E '^v?[0-9]+\.[0-9]+' | grep -v '^active$' || true)
    if [ -z "$versions" ];then
        echo "No versions installed."
        return
    fi

    echo "Installed versions:"
    echo ""
    while IFS= read -r version;do
        local version_type="stable"
        if ! is_stable_version "$version"; then
            version_type="pre-release"
        fi

        if [ "$version" == "$active" ];then
            echo "  * $version (ACTIVE - $version_type)"
        else
            echo "    $version ($version_type)"
        fi

        local path="$ASEPRITE_DIR/$version"
        if [ -d "$path" ];then
          local size=$(du -sh "$path" 2>/dev/null | cut -f1)
          echo "    Path: $path"
          echo "    Size: $size"

          local release_date=$(get_active_version_date "$version")
          if [ "$release_date" != "unknown" ] && [ -n "$release_date" ];then
              local formatted_date=$(echo "$release_date" | sed 's/T/ /' | sed 's/Z.*//' | cut -d':' -f1,2)
              echo "    Released: $formatted_date"
          fi
        fi
        echo ""
    done <<< "$versions"
    echo "Active version symlink: $ASEPRITE_DIR/active -> $active"
}

switch_version(){
    echo ""
    echo "===== Switch Version ====="
    echo ""

    if [ ! -d "$ASEPRITE_DIR" ];then
        echo "No versions installed."
        return
    fi

    local versions=$(ls -1 "$ASEPRITE_DIR" | grep -E '^v?[0-9]+\.[0-9]+' | grep -v '^active$' || true)
    if [ -z "$versions" ];then
      echo "No versions installed."
      return
    fi

    local active=$(get_active_version)
    echo "Currently active: $active"
    echo ""
    echo "Available versions:"

    PS3="Select verstion to activate (or Cancel): "
    select version in $versions "Cancel"; do
        if [ "$version" == "Cancel" ] || [ -z "$version" ]; then
            echo "Cancelled."
            return
        fi

        if [ "$version" == "$active" ];then
            echo "Version $version is already active."
            return
        fi

        echo "Switching to version $version..."
        sudo ln -sfn "$ASEPRITE_DIR/$version" "$ASEPRITE_DIR/active"
        sudo ln -sfn "$ASEPRITE_DIR/active/aseprite" /usr/local/bin/aseprite
        sudo tee /usr/share/applications/aseprite.desktop > /dev/null << EOF
[Desktop Entry]
Name=Aseprite
Version=$version
Comment=Animated sprite editor & pixel art tool
Exec=$ASEPRITE_DIR/active/bin/aseprite %F
Icon=$ASEPRITE_DIR/active/share/aseprite/data/icons/ase64.png
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=image/x-aseprite;
EOF
        sudo update-desktop-database /usr/share/applications 2>/dev/null || true
        echo "Successfully switched to version $version!"
        return
    done
}

#------------------------
# Menu display
# -----------------------

show_menu(){
    echo ""
    echo "===== Aseprite Manager ====="
    echo ""
    check_update
    echo ""
    echo "1) Install Aseprite"
    echo "2) Uninstall Aseprite"
    echo "3) Switch Active Version"
    echo "4) List All Versions (detailed)"
    echo "5) Quit"
    echo ""
}

while true; do
    show_menu
    read -rp "Choose an option: " choice
    case "$choice" in
        1) install_version ;;
        2) uninstall ;;
        3) switch_version ;;
        4) list_all_versions ;;
        5) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    echo ""
    read -rp "Press Enter to continue..."
    echo ""
done
