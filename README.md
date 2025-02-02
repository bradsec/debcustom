# Debian Splash Screen Customization

A bash script for customizing Debian-based Linux systems' splash screens, including GRUB bootloader background and disk encryption password entry screen.

## Note

Testing has only been done on Debian 12.

## Features

- Customize GRUB bootloader background image
- Customize disk encryption password entry screen background
- Configurable password entry bullet/dot image
- Multiple password entry position options
- Adjustable bullet/dot spacing
- Automatic image format conversion (JPEG to PNG)
- Automatic bullet image resizing (max 24px)
- Error handling and dependency checking

## Requirements

- Debian-based Linux system (Debian, Ubuntu, etc.)
- Root/sudo privileges
- Required packages (automatically installed):
  - plymouth
  - imagemagick
  - file

## Installation

```bash
# Clone the repository
git clone https://github.com/bradsec/debcustom.git

# Navigate to directory
cd debcustom

# Make script executable
chmod +x debcustom.sh
```

### Usage Options

```terminal
Usage: sudo debcustom.sh [-g grub_image_path] [-u unlock_image_path] [-b unlock_bullet_image_path] [-s unlock_bullet_spacing] [-p position]
Options:
  -g : Path to grub background image (PNG or JPEG)
  -u : Path to unlock background image (PNG or JPEG)
  -b : Path to password dot/bullet image (PNG or JPEG)
  -s : Set spacing between password entry bullet images (0.2 - 2.0)
  -p : Password entry position (top-left, top-center, top-right, middle-left,
       middle-center, middle-right, bottom-left, bottom-center, bottom-right)
  -r : Restore original settings
  -h : Show this help message
```

### Available Password Entry Positions

- `top-left` (default)
- `top-center`
- `top-right`
- `middle-left`
- `middle-center`
- `middle-right`
- `bottom-left`
- `bottom-center`
- `bottom-right`

### Examples

```bash
# Use all defaults
sudo ./debcustom.sh

# Custom background grub background image
sudo ./debcustom.sh -g /path/to/background.png

# Custom disk encryption background image, passoword entry bullet image, password entry position
sudo ./debcustom.sh -u /path/to/background.png -b /path/to/bullet.png -p bottom-right

# Restore original settings
sudo ./debcustom.sh -r
```

## Default Settings

- GRUB Background Image: `custom_background.png` in script directory
- Unlock Background Image: `custom_background.png` in script directory
- Unlock Bullet Image: `custom_bullet.png` in script directory
- Password Entry Position: `top-left`
- Unlock Bullet Spacing: `1.2`

## Included demo images (replace with your preferred images)

- `custom_background.png`
- `custom_unlock_bullet.png`

## Features in Detail

### GRUB Customization
- Enables quiet splash mode
- Sets custom background image

### Encryption Screen Customization
- Custom background image
- Custom password entry bullet/dot image
- Configurable password entry position with 9 preset positions
- Adjustable bullet spacing for password entry feedback
- Automatic image format conversion and optimization

### Image Processing
- Supports PNG and JPEG formats
- Automatic conversion of JPEG to PNG
- Automatic resizing of bullet images larger than 24px
- Maintains aspect ratio during resizing

## Troubleshooting

1. Make sure the script is run with sudo/root privileges
2. Verify image files exist and are readable
3. Check if system is Debian-based (Ubuntu, Linux Mint, etc.)
4. Ensure internet connection for package installation
5. For GRUB customization, verify GRUB bootloader is installed
6. For encryption screen customization, verify disk encryption is enabled

## Screenshots

### Default Debian 12 GRUB and Encryption Splash Screens 

![image](screenshots/default_grub.png)  
![image](screenshots/default_unlock.png)  

### Customized GRUB and Encryption Splash Screens 

![image](screenshots/new_grub.png)
![image](screenshots/new_unlock.png)  
