#!/bin/bash

#------------------------
# Uninstallation functions
# -----------------------

list_installed_versions(){
    if [ ! -d "$ASEPRITE_DIR" ]; then
        echo "No versions installed." >&2
        return 1
    fi

    local versions=$(ls -1 "$ASEPRITE_DIR" 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+' | grep -v '^active$' || true)
    if [ -z "$versions" ]; then
        echo "No versions installed." >&2
        return 1
    fi

    echo "$versions"
}

get_active_version(){
    if [ -L "$ASEPRITE_DIR/active" ];then
        basename "$(readlink -f "$ASEPRITE_DIR/active")"
    else
        echo "none"
    fi
}

choose_version_to_uninstall(){
    local versions="$1"
    local active=$(get_active_version)

    echo "Installed versions:" >&2
    echo "Active version: $active" >&2
    echo "" >&2

    PS3="Select version to uninstall: "
    select opt in $versions "Uninstall All Versions" "Cancel";do
        if [ "$opt" == "Cancel" ];then
            echo "Uninstall cancelled." >&2
            return 1
        elif [ "$opt" == "Uninstall All Versions" ];then
            echo "All"
            return 0
        elif [ -z "$opt" ]; then
            echo "Invalid selection. Please try again." >&2
            continue
        else
            echo "$opt"
            return 0
        fi
    done
}

remove_system_integration(){
    echo "Removing system integration..." >&2
    if [ -L /usr/local/bin/aseprite ]; then
        sudo rm /usr/local/bin/aseprite
        echo "Removed /usr/local/bin/aseprite symlink" >&2
    fi

    if [ -f /usr/share/applications/aseprite.desktop ];then
        sudo rm /usr/share/applications/aseprite.desktop
        echo "Removed desktop entry" >&2
    fi

    sudo update-desktop-database /usr/share/applications 2>/dev/null || true
    echo "System integration removed!" >&2
}

uninstall_version(){
    local version="$1"
    local install_dir="$ASEPRITE_DIR/$version"

    if [ ! -d "$install_dir" ]; then
        echo "Version $version is not installed." >&2
        return 1
    fi

    echo "Uninstalling Aseprite version $version..." >&2
    local active=$(get_active_version)
    local is_active=false
    if [ "$active" == "$version" ]; then
        is_active=true
    fi

    sudo rm -rf  "$install_dir"
    echo "Removed $install_dir" >&2

    if [ "$is_active" == true ];then
        if [ -L "$ASEPRITE_DIR/active" ];then
            sudo rm "$ASEPRITE_DIR/active"
            echo "Removed active symlink" >&2
        fi

        local remaining=$(list_installed_versions 2>/dev/null)
        if [ -n "$remaining" ];then
            echo "" >&2
            echo "Other versions are still installed:" >&2
            echo "$remaining" >&2
            echo "" >&2
            read -rp "Would you like to activate another version? (y/N): " active_another
            if [[ "$active_another" =~ ^[Yy] ]];then
                PS3="Select version to activate: "
                select new_active in $remaining "Skip"; do
                    if [ "$new_active" == "Skip" ] || [ -z "$new_active" ];then
                        echo "Skipped activation." >&2
                        break
                    else
                        sudo ln -sfn "$ASEPRITE_DIR/$new_active" "$ASEPRITE_DIR/active"
                        echo "Activated version $new_active" >&2
                        break
                    fi
                done
            fi
        else
            remove_system_integration
        fi
    fi

    echo "Successfully uninstalled version $version!" >&2
}

uninstall_all_versions(){
    echo "WARNING: This will remove All installed Aseprite versions!" >&2
    read -rp "Are you sure you want to continue? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy] ]];then
        echo "Uninstallin all Aseprite versions..." >&2
        if [ -d "$ASEPRITE_DIR" ]; then
            sudo rm -rf "$ASEPRITE_DIR"
            echo "Removed $ASEPRITE_DIR" >&2
        fi

        remove_system_integration
        echo "Successfully uninstalled all versions!" >&2
    else
        echo "Uninstall cancelled." >&2
        return 1
    fi
}

uninstall(){
    echo ""
    echo "===== Uninstall Aseprite ====="
    echo ""

    local versions
    versions=$(list_installed_versions)

    if [ $? -ne 0 ]; then
        echo "Nothing to uninstall." >&2
        return 0
    fi

    local chosen
    chosen=$(choose_version_to_uninstall "$versions")
    local choice_result=$?

    if [ $choice_result -ne 0 ];then
        return 1
    fi

    if [ "$chosen" == "All" ];then
        uninstall_all_versions
    else
        uninstall_version "$chosen"
    fi
}
