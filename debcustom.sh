#!/bin/bash

# Exit on error
set -e

# Enable debug mode with -x flag
if [[ "$*" == *"-x"* ]]; then
    set -x
fi

log_date() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

term_error() {
    log_date "[${RED}ERROR${RESET}] $1" >&2
    exit 1
}

term_info() {
    log_date "[${CYAN}INFO${RESET}] $1" >&2
}

term_warn() {
    log_date "[${YELLOW}WARNING${RESET}] $1" >&2
}

term_done() {
    log_date "[${GREEN}DONE${RESET}] $1" >&2
}



term_colors() {
    # Set colors for use in print_message TASK terminal output functions
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        CYAN=$(printf '\033[36m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        ORANGE=$(printf '\033[38;5;208m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[0m')
        CLEAR_LINE=$(tput el)
    else
        RED=""
        GREEN=""
        CYAN=""
        YELLOW=""
        BLUE=""
        ORANGE=""
        BOLD=""
        RESET=""
        CLEAR_LINE=""
    fi
}

wait_for() {
    echo
    if [ -z "${2}" ]; then
        message="Do you wish to continue"
    else
        message="${2}"
    fi

    case "${1}" in
        user_anykey) read -n 1 -s -r -p "[${GREEN}USER${RESET}] Press any key to continue. "
        echo -e "\n"
        ;;
        user_continue) local response
        while true; do
            read -r -p "[${GREEN}USER${RESET}] ${message} (y/N)?${RESET} " response
            case "${response}" in
            [yY][eE][sS] | [yY])
                echo
                break
                ;;
            *)
                echo
                exit
                ;;
            esac
        done;;
        *) echo "Invalid function usage.";;
    esac
}

# Function to check if running as root
check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        term_error "Script must be run as root or with sudo"
    else
        term_info "Root or superuser detected"
    fi
}

# Check if required command exists
require_command() {
    command -v "$1" >/dev/null 2>&1 || term_error "Required command '$1' not found. Please install it."
}

# Function to backup original settings
backup_original_settings() {
    local backup_dir="/usr/local/share/custom-theme-backup"
    
    # Check if backup already exists
    if [ -f "$backup_dir/.backup_completed" ]; then
        term_info "Backup already exists, skipping backup process"
        return 0
    fi
    
    term_info "Backing up original settings..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Backup GRUB settings if GRUB is installed
    if check_grub; then
        if [ -f "/etc/default/grub" ]; then
            cp "/etc/default/grub" "$backup_dir/grub.backup"
        fi
    fi
    
    # Backup Plymouth theme settings
    if [ -f "/etc/plymouth/plymouthd.conf" ]; then
        cp "/etc/plymouth/plymouthd.conf" "$backup_dir/plymouthd.conf.backup"
    fi
    
    # Save the currently active Plymouth theme
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme | tr -d '\n' > "$backup_dir/active_theme.backup"
    fi
    
    # Create a marker file to indicate backup is complete
    touch "$backup_dir/.backup_completed"
    
    term_info "Original settings backed up to $backup_dir"
}

# Function to restore original settings
restore_original_settings() {
    local backup_dir="/usr/local/share/custom-theme-backup"
    term_info "Restoring original settings..."
    
    # Check if backup exists
    if [ ! -d "$backup_dir" ]; then
        term_error "No backup found to restore from"
        return 1
    fi
    
    # Restore GRUB settings if backup exists
    if [ -f "$backup_dir/grub.backup" ]; then
        cp "$backup_dir/grub.backup" "/etc/default/grub"
        update-grub
        term_info "GRUB settings restored"
    fi
    
    # Restore Plymouth settings if backup exists
    if [ -f "$backup_dir/plymouthd.conf.backup" ]; then
        cp "$backup_dir/plymouthd.conf.backup" "/etc/plymouth/plymouthd.conf"
    fi
    
    # Restore original Plymouth theme
    if [ -f "$backup_dir/active_theme.backup" ]; then
        local original_theme=$(cat "$backup_dir/active_theme.backup")
        if [ -n "$original_theme" ]; then
            plymouth-set-default-theme -R "$original_theme"
            term_info "Plymouth theme restored to: $original_theme"
        fi
    fi
    
    # Remove custom theme if it exists
    if [ -d "/usr/share/plymouth/themes/custom-theme" ]; then
        rm -rf "/usr/share/plymouth/themes/custom-theme"
        term_info "Custom theme removed"
    fi
    
    # Update initramfs
    update-initramfs -u
    
    term_done "Original settings restored successfully!"
}

validate_image() {
    local image_path="$1"
    local is_bullet="${2:-false}"  # Optional parameter to indicate if this is a bullet image
    local max_bullet_size=24       # Maximum size for bullet images
    local max_image_size=1024

    # Check if file exists
    if [[ ! -f "$image_path" ]]; then
        term_error "File does not exist: $image_path"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$image_path" ]]; then
        term_error "File is not readable: $image_path"
        return 1
    fi

    require_command "file"
    require_command "identify"
    require_command "convert"
    local mime_type

    mime_type=$(file --mime-type -b "$image_path")

    # If it's a bullet image, check dimensions and resize if needed
    if [[ "$is_bullet" == "true" ]]; then       
        # Get image dimensions
        local dimensions
        dimensions=$(identify -format "%wx%h" "$image_path")
        local width=${dimensions%x*}
        local height=${dimensions#*x}
        
        # Check if either dimension is larger than max_bullet_size
        if (( width > max_bullet_size )) || (( height > max_bullet_size )); then
            term_info "Resizing bullet image to maximum ${max_bullet_size}px..."
            local temp_file="/tmp/resized_$(basename "$image_path")"
            
            # Resize maintaining aspect ratio, setting largest dimension to max_bullet_size
            convert "$image_path" -resize "${max_bullet_size}x${max_bullet_size}>" "$temp_file" || term_error "Bullet image resize failed"
            image_path="$temp_file"
        fi
    else      
        # Get image dimensions
        local dimensions
        dimensions=$(identify -format "%wx%h" "$image_path")
        local width=${dimensions%x*}
        local height=${dimensions#*x}
        
        # Check if either dimension is larger than max_image_size
        if (( width > max_image_size )) || (( height > max_image_size )); then
            term_info "Resizing background image to maximum ${max_image_size}px..."
            local temp_file="/tmp/resized_$(basename "$image_path")"
            
            # Resize maintaining aspect ratio, setting largest dimension to max_image_size
            convert "$image_path" -resize "${max_image_size}x${max_image_size}>" "$temp_file" || term_error "Bullet image resize failed"
            image_path="$temp_file"
        fi
    fi

    case "$mime_type" in
        image/png)
            echo "$image_path"
            ;;
        image/jpeg|image/jpg)
            require_command "convert"
            term_info "Converting image to PNG format..."
            local temp_file="/tmp/converted_$(basename "$image_path" | sed 's/\.[^.]*$//').png"
            convert "$image_path" "$temp_file" || term_error "Image conversion failed"
            echo "$temp_file"
            ;;
        *)
            term_error "Invalid image format. Please use PNG or JPEG files."
            ;;
    esac
}

# Check if GRUB is installed
check_grub() {
    if command -v grub-install >/dev/null 2>&1 && [ -f "/etc/default/grub" ]; then
        term_info "GRUB bootloader detected"
        return 0
    else
        term_warn "GRUB bootloader not detected, skipping GRUB customization"
        return 1
    fi
}

# Check if disk encryption is enabled
check_encryption() {
    if grep -Eq "^\s*[^#]+.*\s+crypt" /etc/fstab || [ -s "/etc/crypttab" ]; then
        term_info "Disk encryption detected"
        return 0
    else
        term_warn "No disk encryption detected, skipping encryption screen customization"
        return 1
    fi
}

# Function to install dependencies
install_dependencies() {
    term_info "Installing required dependencies..."
    # Check if we're on a Debian/Ubuntu system
    if [ ! -f "/etc/debian_version" ]; then
        term_error "This script is currently only supported on Debian/Ubuntu-based systems"
    fi

    # Update package lists
    apt-get update || term_error "Failed to update package lists"

    # Define required packages based on desktop environment
    local PACKAGES="plymouth imagemagick file"

    # Install packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES || term_error "Failed to install dependencies"

    # Verify critical commands exist
    local REQUIRED_COMMANDS="gsettings dconf plymouth-set-default-theme update-initramfs"
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v $cmd >/dev/null 2>&1; then
            term_error "Required command '$cmd' not found after installing dependencies"
        fi
    done
}

# Setup GRUB background
setup_grub_background() {
    local image_path="$1"
    term_info "Setting up GRUB background"

    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

    mkdir -p /usr/local/share/images
    cp "$image_path" /usr/local/share/images/custom-grub.png

    sed -i '/GRUB_BACKGROUND/d' /etc/default/grub
    echo 'GRUB_BACKGROUND="/usr/local/share/images/custom-grub.png"' >> /etc/default/grub

    update-grub
}

# Function to setup encryption screen background
setup_encryption_background() {
    local image_path="$1"
    local position="${2:-top-left}"  # Default to top-left if not specified
    local bullet_path="$3"
    local bullet_filename=$(basename "$bullet_path")
    local custom_unlock_bullet_spacing="$4"
    term_info "Setting up encryption screen background"
    
    local theme_dir="/usr/share/plymouth/themes/custom-theme"
    mkdir -p "$theme_dir"
    
    # Copy and set up images
    cp "$image_path" "$theme_dir/background.png"
    cp "$bullet_path" "$theme_dir/"

   
    # Create Plymouth theme configuration
    cat > "$theme_dir/custom-theme.plymouth" << EOF
[Plymouth Theme]
Name=Custom Theme
Description=Custom theme with background image
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/custom-theme
ScriptFile=/usr/share/plymouth/themes/custom-theme/custom-theme.script
EOF
    
    # Create theme script with position
    cat > "$theme_dir/custom-theme.script" << EOF
# Set password entry position
global.custom_unlock_entry_position = "${position}";

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

# Load background image
bg_image = Image("background.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
resized_image = bg_image.Scale(screen_width, screen_height);
sprite = Sprite(resized_image);
sprite.SetPosition(0, 0, -100);

# Password prompt state
prompt_active = 0;

# Text colors
text_colour.red = 1.0;
text_colour.green = 1.0;
text_colour.blue = 1.0;

fun get_position_coordinates() {
    # Get screen dimensions
    screen_width = Window.GetWidth();
    screen_height = Window.GetHeight();
    
    # Set padding from edges
    local.padding = 50;
    
    # Calculate center positions
    local.center_x = Math.Int(screen_width / 2);
    local.center_y = Math.Int(screen_height / 2);
    
    # Define positions hash
    positions = [];
    
    # Top positions
    positions["top-left"] = [padding, padding];
    positions["top-center"] = [center_x - 100, padding];
    positions["top-right"] = [screen_width - 250 - padding, padding];
    
    # Middle positions
    positions["middle-left"] = [padding, center_y - 50];
    positions["middle-center"] = [center_x - 100, center_y - 50];
    positions["middle-right"] = [screen_width - 250 - padding, center_y - 50];
    
    # Bottom positions
    positions["bottom-left"] = [padding, screen_height - 100];
    positions["bottom-center"] = [center_x - 100, screen_height - 100];
    positions["bottom-right"] = [screen_width - 250 - padding, screen_height - 100];
    
    return positions;
}

fun WriteText(text, colour) {
    image = Image.Text(text, colour.red, colour.green, colour.blue);
    return image;
}

fun ImageFromText(text) {
    image = WriteText(text, text_colour);
    return image;
}

fun password_dialogue_setup(message_text) {
    local.entry;
    local.bullet_image;
    
    bullet_image = Image("$bullet_filename");
    
    # Get position coordinates
    local.positions = get_position_coordinates();
    local.position = global.custom_unlock_entry_position;
    
    if (!positions[position]) {
        position = "top-left";  # Fallback to top-left if invalid position
    }
    
    entry.x = positions[position][0];
    entry.y = positions[position][1];
    entry.z = 10000;
    
    entry.sprite.SetPosition(entry.x, entry.y, entry.z);
    entry.sprite.SetOpacity(0);
    
    local.message = ImageFromText(message_text);
    local.message_sprite = Sprite(local.message);
    local.message_sprite.SetPosition(entry.x, entry.y - 20, entry.z);
    
    global.password_dialogue = local;
}

fun display_password_callback(prompt, bullets) {
    global.status = "password";
    if (!global.password_dialogue) {
        password_dialogue_setup(prompt);
    }
    
    for (i = 0; password_dialogue.bullet[i]; i++) {
        password_dialogue.bullet[i].sprite.SetOpacity(0);
    }
    
    local.bullet_width = password_dialogue.bullet_image.GetWidth();
    local.bullet_spacing = Math.Int(bullet_width * $custom_unlock_bullet_spacing);
    local.bullet_y = password_dialogue.entry.y + 10;
    
    for (i = 0; i < bullets; i++) {
        local.bullet_x = password_dialogue.entry.x + (i * local.bullet_spacing);
        
        if (!password_dialogue.bullet[i]) {
            password_dialogue.bullet[i].sprite = Sprite(password_dialogue.bullet_image);
            password_dialogue.bullet[i].sprite.SetPosition(local.bullet_x, local.bullet_y, password_dialogue.entry.z + 1);
        }
        password_dialogue.bullet[i].sprite.SetOpacity(1);
    }
}

fun display_normal_callback() {
    global.status = "normal";
    if (global.password_dialogue) {
        password_dialogue.entry.sprite.SetOpacity(0);
        password_dialogue.message_sprite.SetOpacity(0);
        for (i = 0; password_dialogue.bullet[i]; i++) {
            password_dialogue.bullet[i].sprite.SetOpacity(0);
        }
        global.password_dialogue = NULL;
        prompt_active = 0;
    }
}

Plymouth.SetDisplayPasswordFunction(display_password_callback);
Plymouth.SetDisplayNormalFunction(display_normal_callback);

fun refresh_callback() {
    # Required for proper refresh
}
Plymouth.SetRefreshFunction(refresh_callback);
EOF
    
    # Register and enable the theme
    plymouth-set-default-theme -R custom-theme
    
    # Update initramfs
    update-initramfs -u
}

main() {
    local custom_grub_background="custom_background.png"  # Default custom background image for GRUB
    local custom_unlock_background="custom_background.png"  # Default custom background image for unlock disk encryption
    local custom_unlock_bullet="custom_unlock_bullet.png" # Default dot/bullet image for password entry
    local custom_unlock_entry_position="top-left"  # Default position of password entry
    local custom_unlock_bullet_spacing="1.2" # Default spacing between bullet images during password entry
    local restore_mode=false
    local OPTIND opt
    
    # Print usage/help function
    usage() {
        echo "Usage: $0 [-g grub_image_path] [-u unlock_image_path] [-b unlock_bullet_image_path] [-s unlock_bullet_spacing] [-p position]"
        echo "Options:"
        echo "  -g : Path to grub background image (PNG or JPEG)"
        echo "  -u : Path to unlock background image (PNG or JPEG)"
        echo "  -b : Path to password dot/bullet image (PNG or JPEG)"
        echo "  -s : Set spacing between password entry bullet images (0.2 - 2.0)"
        echo "  -p : Password entry position (top-left, top-center, top-right, middle-left,"
        echo "       middle-center, middle-right, bottom-left, bottom-center, bottom-right)"
        echo "  -r : Restore original settings"
        echo "  -h : Show this help message"
        echo
        exit 1
    }

    # Parse command line options
    while getopts "g:u:p:b:s:rh" opt; do
        case $opt in
            g) custom_grub_background="$OPTARG";;
            u) custom_unlock_background="$OPTARG";;
            b) custom_unlock_bullet="$OPTARG";;
            s) custom_unlock_bullet_spacing="$OPTARG";;
            p) custom_unlock_entry_position="$OPTARG";;
            r) restore_mode=true;;
            h) usage;;
            ?) usage;;
        esac
    done

    clear
    term_colors
    echo
    echo "--------------------------------------------------------------"
    echo "  Debian GRUB and Disk Encryption Unlock Image Customization  "
    echo "  Created by bradsec @ github.com"
    echo "--------------------------------------------------------------"
    echo

    check_root

    if [ "$restore_mode" = true ]; then
        restore_original_settings
        exit 0
    fi

    install_dependencies

    # Backup original settings before making changes
    backup_original_settings

    # Validate and convert image if required
    custom_grub_background=$(validate_image "${custom_unlock_background}")
    custom_unlock_background=$(validate_image "${custom_unlock_background}")
    custom_unlock_bullet=$(validate_image "${custom_unlock_bullet}" true)

    # Validate the entry position
    local valid_positions=("top-left" "top-center" "top-right" "middle-left" "middle-center" "middle-right" "bottom-left" "bottom-center" "bottom-right")
    if ! [[ " ${valid_positions[*]} " =~ " $custom_unlock_entry_position " ]]; then
        term_error "Invalid entry position: $custom_unlock_entry_position. Valid positions are: ${valid_positions[*]}"
    fi

    # Configure GRUB background (if applicable and not skipped)
    if $(check_grub); then
        setup_grub_background "${custom_unlock_background}"
    fi

    # Configure encryption screen background (if applicable and not skipped)
    if $(check_encryption); then
        setup_encryption_background "${custom_unlock_background}" "${custom_unlock_entry_position}" "${custom_unlock_bullet}" "${custom_unlock_bullet_spacing}"
    fi

    term_done "Customization completed successfully!"
}

main ${@}