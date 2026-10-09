#!/bin/bash
#
# ==============================================================================
# Script Name : area.sh
# Author      : Anu
# ==============================================================================
# Description :
#   This script prompts the user to enter the width and height of a
#   rectangle in centimetres, validates that both values are numeric
#   (accepting both integers and floating point numbers), then calculates
#   and displays the area of the rectangle in both square centimetres and
#   square inches. The user is then given the option to enter another
#   rectangle or quit the program. All interaction is done through Zenity
#   graphical dialogue boxes.
#
# How to run :
#   Make the script executable, then run it from a terminal that has a
#   graphical display available (Zenity requires an X/Wayland session):
#       chmod +x area.sh
#       ./area.sh
#   The script needs no arguments and runs in interactive mode only.
#
# Requirements / Assumptions :
#   - Zenity must be installed (sudo apt install zenity).
#   - The bc command must be available for floating point arithmetic.
#   - The script assumes a graphical desktop session is available so that
#     Zenity dialogue boxes can be displayed.
#
# Output :
#   The calculated area is displayed on screen via a Zenity info dialogue,
#   shown in both square centimetres and square inches. No file output is
#   produced.
#
# Conversion constant : 1 inch = 2.54 cm, so 1 sq inch = 2.54 * 2.54 sq cm.
# ==============================================================================

# Regular expression used to validate that user input is a positive
# integer or positive floating point number (e.g. 12, 3.142, 0.5).
NUMBER_REGEX='^[0-9]+([.][0-9]+)?$'

# ------------------------------------------------------------------------
# Function : get_dimension
# Purpose  : Repeatedly prompts the user (via Zenity) for a single
#            dimension until a valid positive number is entered.
# Arguments: $1 - the label to show in the prompt (e.g. "width")
# Returns  : Echoes the validated numeric value to stdout.
# ------------------------------------------------------------------------
get_dimension() {
    local label="$1"
    local value=""

    while true; do
        value=$(zenity --entry \
            --title="Rectangle Area Calculator" \
            --text="Enter the ${label} of the rectangle in centimetres:")

        # If the user pressed Cancel, zenity returns a non-zero exit code
        # and an empty string - exit the whole script gracefully.
        if [ $? -ne 0 ]; then
            zenity --info --text="Program cancelled by user. Goodbye."
            exit 0
        fi

        # Validate the entered value against the number regex.
        if [[ $value =~ $NUMBER_REGEX ]] && (( $(echo "$value > 0" | bc -l) )); then
            echo "$value"
            return 0
        else
            zenity --error \
                --text="Invalid input: '${value}'.\nPlease enter a positive number (e.g. 12 or 3.5)."
        fi
    done
}

# ------------------------------------------------------------------------
# Function : calculate_area
# Purpose  : Calculates the rectangle area in cm^2 from width and height,
#            then converts that area to square inches.
# Arguments: $1 - width in cm, $2 - height in cm
# Returns  : Echoes "area_cm area_inches" separated by a space.
# ------------------------------------------------------------------------
calculate_area() {
    local width="$1"
    local height="$2"
    local area_cm area_inches

    area_cm=$(echo "$width * $height" | bc -l)
    # 1 inch = 2.54 cm  ->  1 sq inch = 2.54 * 2.54 sq cm
    area_inches=$(echo "$area_cm / (2.54 * 2.54)" | bc -l)

    printf "%.4f %.4f" "$area_cm" "$area_inches"
}

# ==============================================================================
# Main program loop
# ==============================================================================
while true; do
    width=$(get_dimension "width")
    height=$(get_dimension "height")

    read -r area_cm area_inches <<< "$(calculate_area "$width" "$height")"

    zenity --info \
        --title="Result" \
        --text="Width  : ${width} cm\nHeight : ${height} cm\n\nArea = ${area_cm} sq cm\nArea = ${area_inches} sq inches"

    # Ask the user whether to calculate another rectangle or quit.
    zenity --question \
        --title="Continue?" \
        --text="Would you like to calculate another rectangle?"

    # zenity --question returns 0 for Yes, 1 for No.
    if [ $? -ne 0 ]; then
        zenity --info --text="Thank you for using the Rectangle Area Calculator. Goodbye."
        break
    fi
done

exit 0
