#!/bin/bash

#------------------------
# Installation functions
# -----------------------

check_dependencies(){
    echo "Checking required dependencies..."
    packages=(g++ clang cmake ninja-build libc++-dev libc++abi-dev libx11-dev libxcursor-dev libxi-dev libxrandr-dev libgl1-mesa-dev libfontconfig1-dev curl unzip ccache)
    missing=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null;then
            missing+=("$pkg")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Installing missing packages: ${missing[*]}"
        sudo apt update
        sudo apt install -y "${missing[@]}"
    else
        echo "All dependencies are already installed."
    fi
}

fetch_latest_releases() {
    echo "Fetching latest 5 Aseprite releases..." >&2
    local releases_json=$(curl -s https://api.github.com/repos/aseprite/aseprite/releases | head -c 50000)
    if [ -z "$releases_json" ]; then
        echo "Failed to fetch releases." >&2
        return 1
    fi
    echo "$releases_json" | grep -Po '"tag_name": "\K.*?(?=")' | head -5
}

choose_version(){
    local releases="$1"
    echo "Available versions:" >&2
    PS3="Select version: "
    select opt in $releases "Enter custom version" "Cancel"; do
        if [ "$opt" == "Cancel" ]; then
            echo "Installation cancelled." >&2
            return 1
        elif [ "$opt" == "Enter custom version" ];then
            read -rp "Enter version tag (e.g, v.1.3.16) : " custom_version
            if [ -z "$custom_version" ];then
                echo "No version entered. Please try again." >&2
                continue
            fi

            if [[ ! "$custom_version" =~ ^v ]]; then
                custom_version="v$custom_version"
            fi
            echo "$custom_version"
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

download_skia() {
    local skia_dir="$1"
    echo "Downloading Skia..." >&2
    mkdir -p "$skia_dir"

    if ! curl -f -L --progress-bar -o "$skia_dir/skia.zip" "https://github.com/aseprite/skia/releases/latest/download/Skia-Linux-Release-x64.zip"; then
        echo "Failed to download Skia" >&2
        return 1
    fi

    if [ ! -s "$skia_dir/skia.zip" ];then
        echo "Skia zip file is empty or missing" >&2
        return 1
    fi

    echo "Extracting Skia..." >&2
    if ! unzip -q "$skia_dir/skia.zip" -d "$skia_dir"; then
        echo "Failed to extract Skia" >&2
        return 1
    fi
    rm "$skia_dir/skia.zip"
}

get_source_download_url(){
    local tag="$1"
    echo "Finding source file for $tag..." >&2
    local release_json=$(curl -s "https://api.github.com/repos/aseprite/aseprite/releases/tags/$tag")
    local asset_url=$(echo "$release_json" | grep -Po '"browser_download_url": "\K[^"]*Source\.zip')
    if [ -z "$asset_url" ];then
        echo "Could not find source zip for $tag" >&2
        return 1
    fi

    echo "$asset_url"
}

download_aseprite(){
    local version="$1"
    local src_dir="$2"
    echo "Downloading Aseprite source for $version..." >&2
    mkdir -p "$src_dir"

    local url=$(get_source_download_url "$version")
    if [ -z "$url" ];then
        echo "Failed to get download URL" >&2
        return 1
    fi
    echo "Downloading from: $url" >&2

    if ! curl -f -L --progress-bar -o "$src_dir/aseprite.zip" "$url";then
        echo "Failed to download Aseprite" >&2
        return 1
    fi

    if [ ! -s "$src_dir/aseprite.zip" ];then
        echo "Skia zip file is empty or missing" >&2
        return 1
    fi

    local filesize=$(stat -f%z "$src_dir/aseprite.zip" 2>/dev/null || stat -c%s "$src_dir/aseprite.zip" 2>/dev/null)
    echo "Downloaded file size: $filesize bytes" >&2

    echo "Extracting Aseprite..." >&2
    if ! unzip -q "$src_dir/aseprite.zip" -d "$src_dir"; then
        echo "Failed to extract Aseprite" >&2
        return 1
    fi
    rm "$src_dir/aseprite.zip"
}

build_aseprite(){
    local src_dir="$1"
    local skia_dir="$2"
    local version="${3#v}"
    local install_dir="$4"
    local build_dir="$src_dir/build"

    cd "$SRC_DIR" || { echo "Source folder not found"; return 1; }
    mkdir -p "$build_dir"
    cd "$build_dir" || { echo "Build folder creation failed"; return 1; }

    local max_jobs=$(nproc)
    echo "Your system has $max_jobs CPU cores available." >&2
    read -rp "Enter number of jobs to use (press Enter for $max_jobs): " num_jobs

    if [ -z "$num_jobs" ];then
        num_jobs=$max_jobs
    fi

    echo "Building Aseprite with $num_jobs parallel jobs..." >&2
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
          -DCMAKE_INSTALL_PREFIX="$install_dir" \
          -DLAF_BACKEND=skia \
          -DSKIA_DIR="$skia_dir" \
          -DSKIA_LIBRARY_DIR="$skia_dir/out/Release-x64" \
          -DSKIA_LIBRARY="$skia_dir/out/Release-x64/libskia.a" \
          -G Ninja ..

    ninja -j"$num_jobs" aseprite || { return 1 ;}
}

install_aseprite(){
    local version="$1"
    local src_dir="$2"
    local build_dir="$src_dir/build"

    echo "Installing Aseprite version $version..."
    local install_dir="$ASEPRITE_DIR/$version"
    sudo mkdir -p "$install_dir"

    cd "$build_dir" || {
        echo "Build directory not found" >&2
        return 1
    }
    sudo ninja install || {
        echo "Ninja install failed!" >&2
        return 1
    }
    sudo ln -sfn "$install_dir" "$ASEPRITE_DIR/latest"

    setup_system_integration "$version"
    echo "Installed version $version and set as active."
}

setup_system_integration(){
    local version="$1"

    echo "Setting up system integration..." >&2

    sudo ln -sf "$ASEPRITE_DIR/latest/bin/aseprite" /usr/local/bin/aseprite
    sudo tee /usr/share/applications/aseprite.desktop > /dev/null << EOF
[Desktop Entry]
Name=Aseprite
Version=$version
Comment=Animated sprite editor & pixel art tool
Exec=$ASEPRITE_DIR/latest/aseprite %F
Icon=$ASEPRITE_DIR/latest/data/icons/ase64.png
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=image/x-aseprite;
EOF

    sudo update-desktop-database /usr/share/applications 2>/dev/null || true

    echo "System integration complete!" >&2
}

cleanup(){
    local temp_dir="$1"
    echo "Cleaning temporary build files..."
    rm -rf "$temp_dir"
}

install_version(){
    local ASEPRITE_SRC_DIR="/tmp/aseprite-build-$$"
    local SKIA_DIR="$ASEPRITE_SRC_DIR/skia"

    echo "===== Install Aseprite ====="
    check_dependencies
    mkdir -p "$ASEPRITE_SRC_DIR" "$SKIA_DIR"

    local releases
    releases=$(fetch_latest_releases) || {
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    }

    local chosen_version
    chosen_version=$(choose_version "$releases")
    local choice_result=$?

    if [ $choice_result -ne 0 ]; then
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    fi

    if [ -z "$chosen_version" ]; then
        echo "No version selected. Aborting installation." >&2
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    fi

    download_aseprite "$chosen_version" "$ASEPRITE_SRC_DIR" || {
        echo "Download failed. Aboring installation." >&2
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    }

    download_skia "$SKIA_DIR" || {
        echo "Skia download failed. Aborting installation." >&2
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    }

    local install_dir="$ASEPRITE_DIR/$chosen_version"
    build_aseprite "$ASEPRITE_SRC_DIR" "$SKIA_DIR" "$chosen_version" "$install_dir" || {
        echo "Build failed. Aborting installation." >&2
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    }

    install_aseprite "$chosen_version" "$ASEPRITE_SRC_DIR" || {
        echo "Installation failed." >&2
        cleanup "$ASEPRITE_SRC_DIR"
        return 1
    }

    cleanup "$ASEPRITE_SRC_DIR"
    echo "Installation complete!" >&2
}
