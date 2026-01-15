# AsepriteManager

AsepriteManager is a Bash script that helps you download, compile, install, and manage multiple versions of Aseprite on Linux systems.

> **Note:** This script is intended for **Debian-based distros only**.
> Feel free to adapt it for other distributions if needed.

## About Aseprite Licensing

Aseprite is **not free software** in its distributed binary form.  
Although its source code is publicly available, **compiled binaries are subject to Aseprite’s commercial license**.

This script:
- Builds Aseprite **from the official source code**
- Is intended for **personal and educational use only**
- Does **not** provide or distribute prebuilt binaries
- Does **not** bypass Aseprite’s licensing system

If you use Aseprite regularly or professionally, 
please purchase a license from: https://www.aseprite.org

> **Legal Notice**: This script is licensed separately from Aseprite.  
> It does **not** grant any rights to the Aseprite software.  
> Any distribution of compiled Aseprite binaries must comply with Aseprite’s official licensing terms.


## Features

- Automatically fetches the **5 latest Aseprite source releases**
- Download and extracts the **Skia** library
- Install all required dependencies (cmake, g++, ninja, etc.)
- Supports installing **multiple versions of Aseprite**
- Allows switching between installed versions
- Uninstall a specific version or all versions

---

## Installation & Usage

```bash
# grant execute permission
chmod +x aseprite_manager.sh

# launch the script
./aseprite_manager.sh
```

## Customizing installation location

By default, Aseprite is installed to :
```bash
ASEPRITE_DIR="/opt/aseprite"
```

You can change this path direclty in [aseprite_manager.sh](./aseprite_manager.sh)

## Compatibility

This script has been tested on:

- PopOs 24.04

Other Debian-based distributions may work but are not guaranteed.

## License

This script is licensed under a [AsepriteManager Non-Commercial License](LICENSE).  
It applies **only to this project**, not to Aseprite software itself.

This project is **not affiliated with or endorsed by Aseprite**.

## Contributing

Contributions are welcome! However, please note:

- This script is intended for **personal and educational use** only.  
- Any contributions should **respect the non-commercial license** of this project.  
- You may submit bug reports, feature requests, or pull requests for improvements to the script itself.  
- Do **not** include or distribute compiled Aseprite binaries in your contributions.  
- Always keep the license and copyright notice intact in any submitted code.

By contributing, you agree that your contributions will follow the same license as this project.
