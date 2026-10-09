#!/bin/bash
###############################################################################
# blackjack.sh                                                    Author: Anu
###############################################################################
#
# WHAT THIS DOES
#   A Blackjack game played entirely through Zenity graphical dialogue
#   boxes (no typing into a plain terminal prompt). One computer-controlled
#   dealer faces off against one or more human players. A shuffled 52-card
#   deck is dealt from and depleted as the game progresses - a card handed
#   to any player or the dealer is taken out of the pack, so it cannot
#   come up again in the same round. Each player is shown their hand and
#   clicks "Hit" or "Stand"; afterwards the dealer's hidden card is
#   revealed and the dealer hits automatically until reaching 17+. Every
#   player is then scored against the dealer as a win, loss, bust or push,
#   and a running points total is kept across as many rounds as the user
#   wants to play.
#
# RUNNING IT
#   chmod +x blackjack.sh
#   ./blackjack.sh
#   Run from a session that has a graphical display available (Zenity
#   requires an X/Wayland session). Takes no command-line arguments -
#   everything is asked for through pop-up dialogue boxes: number of
#   players first, then each player's name, then the game itself repeats
#   until told to stop.
#
# REQUIREMENTS
#   - Zenity must be installed (sudo apt install zenity).
#
# ASSUMPTIONS MADE WHERE THE BRIEF WAS OPEN-ENDED
#   - The brief mentions a points system as an option rather than a
#     requirement, so no betting/money is tracked; a point is simply
#     awarded per round won.
#   - Ace scoring follows the standard rule: counted as 11 unless that
#     would bust the hand, in which case it drops to 1 automatically.
#   - The five-card-trick/Charlie bonus is described in the brief as an
#     uncommon extra and has been left out; every other rule (blackjack,
#     bust, push, dealer's forced hit under 17) is implemented fully.
#
# WHAT GETS PRODUCED
#   Everything is shown to the player as Zenity dialogue boxes as play
#   happens - hands, hit/stand choices, and the final result table per
#   round. Nothing is written to a file by this script.
###############################################################################

# --- Validation regex -----------------------------------------------------
INT_REGEX='^[0-9]+$'
NAME_REGEX='^[A-Za-z][A-Za-z ]*$'

RANKS=(2 3 4 5 6 7 8 9 10 J Q K A)
SUITS=(Hearts Diamonds Clubs Spades)

# DECK holds the remaining cards, as "RANK-SUIT" strings, e.g. "A-Spades".
DECK=()

# ------------------------------------------------------------------------
# Function : cancelled
# Purpose  : Called whenever a Zenity dialogue is closed with Cancel or
#            the window's X button, so the whole program can exit the
#            same way everywhere instead of repeating this in every
#            function.
# ------------------------------------------------------------------------
cancelled() {
    zenity --info --title="Blackjack" --text="Program cancelled by user. Goodbye."
    exit 0
}

# ------------------------------------------------------------------------
# Function : gui_ask_int
# Purpose  : Shows a Zenity entry box and re-asks until a whole number
#            within range is entered.
# Arguments: $1 - text to show, $2 - minimum, $3 - maximum
# Returns  : Echoes the validated integer.
# ------------------------------------------------------------------------
gui_ask_int() {
    local text="$1" min="$2" max="$3" value
    while true; do
        value=$(zenity --entry --title="Blackjack" --text="$text")
        [ $? -ne 0 ] && cancelled
        if [[ $value =~ $INT_REGEX ]] && [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
            echo "$value"
            return 0
        else
            zenity --error --title="Blackjack" \
                --text="Invalid input: '${value}'.\nPlease enter a whole number between $min and $max."
        fi
    done
}

# ------------------------------------------------------------------------
# Function : gui_ask_name
# Purpose  : Shows a Zenity entry box and re-asks until a valid name
#            (letters and spaces only) is entered.
# ------------------------------------------------------------------------
gui_ask_name() {
    local text="$1" value
    while true; do
        value=$(zenity --entry --title="Blackjack" --text="$text")
        [ $? -ne 0 ] && cancelled
        if [[ $value =~ $NAME_REGEX ]]; then
            echo "$value"
            return 0
        else
            zenity --error --title="Blackjack" \
                --text="Invalid input: '${value}'.\nPlease enter a name using letters and spaces only."
        fi
    done
}

# ------------------------------------------------------------------------
# Function : gui_yes_no
# Purpose  : Shows a Zenity Yes/No question dialogue.
# Returns  : "y" if Yes was clicked, "n" if No was clicked.
# ------------------------------------------------------------------------
gui_yes_no() {
    local text="$1"
    if zenity --question --title="Blackjack" --text="$text"; then
        echo "y"
    else
        echo "n"
    fi
}

# ------------------------------------------------------------------------
# Function : gui_hit_or_stand
# Purpose  : Shows the player's current hand and asks Hit or Stand using
#            custom button labels on a Zenity question dialogue.
# Returns  : "hit" or "stand"
# ------------------------------------------------------------------------
gui_hit_or_stand() {
    local text="$1"
    if zenity --question --title="Your turn" --text="$text" \
        --ok-label="Hit" --cancel-label="Stand"; then
        echo "hit"
    else
        echo "stand"
    fi
}

# ------------------------------------------------------------------------
# Function : gui_info
# Purpose  : Small wrapper around a Zenity info box so every info popup
#            in the game shares the same title style.
# ------------------------------------------------------------------------
gui_info() {
    local title="$1" text="$2"
    zenity --info --title="$title" --text="$text"
}

# ------------------------------------------------------------------------
# Function : build_deck
# Purpose  : Fills the global DECK array with a fresh 52-card pack.
# ------------------------------------------------------------------------
build_deck() {
    DECK=()
    local rank suit
    for suit in "${SUITS[@]}"; do
        for rank in "${RANKS[@]}"; do
            DECK+=("${rank}-${suit}")
        done
    done
}

# ------------------------------------------------------------------------
# Function : shuffle_deck
# Purpose  : Randomly shuffles the global DECK array in place using a
#            manually written Fisher-Yates shuffle (no external sort/shuf
#            reliance for the core game logic).
# ------------------------------------------------------------------------
shuffle_deck() {
    local n=${#DECK[@]}
    local i j temp
    for (( i = n - 1; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        temp="${DECK[i]}"
        DECK[i]="${DECK[j]}"
        DECK[j]="$temp"
    done
}

# ------------------------------------------------------------------------
# Function : deal_card
# Purpose  : Removes the top card from the global DECK array and stores
#            it in the global DEALT_CARD variable, so that the same card
#            can never be dealt twice. This function must be called on
#            its own line (not inside $(...) command substitution),
#            because command substitution runs in a subshell and would
#            prevent the change to DECK from reaching the caller.
# ------------------------------------------------------------------------
deal_card() {
    local last_index=$(( ${#DECK[@]} - 1 ))
    DEALT_CARD="${DECK[$last_index]}"
    unset "DECK[$last_index]"
    DECK=("${DECK[@]}")   # re-index the array after removing an element
}

# ------------------------------------------------------------------------
# Function : card_rank
# Purpose  : Extracts just the rank portion of a "RANK-SUIT" card string.
# ------------------------------------------------------------------------
card_rank() {
    echo "${1%%-*}"
}

# ------------------------------------------------------------------------
# Function : hand_value
# Purpose  : Calculates the best possible Blackjack value of a hand,
#            treating each Ace as 11 unless that would bust the hand, in
#            which case Aces are counted as 1 one at a time until the
#            hand is 21 or under (or no Aces remain).
# Arguments: $@ - the cards in the hand, e.g. "A-Spades" "K-Clubs"
# Returns  : Echoes the numeric hand value.
# ------------------------------------------------------------------------
hand_value() {
    local total=0
    local aces=0
    local card rank

    for card in "$@"; do
        rank=$(card_rank "$card")
        case "$rank" in
            J|Q|K) total=$(( total + 10 )) ;;
            A)     total=$(( total + 11 )); aces=$(( aces + 1 )) ;;
            *)     total=$(( total + rank )) ;;
        esac
    done

    while [ "$total" -gt 21 ] && [ "$aces" -gt 0 ]; do
        total=$(( total - 10 ))
        aces=$(( aces - 1 ))
    done

    echo "$total"
}

# ------------------------------------------------------------------------
# Function : is_blackjack
# Purpose  : Reports whether a two-card hand is a natural 21.
# Arguments: $@ - exactly two cards.
# Returns  : "y" or "n"
# ------------------------------------------------------------------------
is_blackjack() {
    if [ "$#" -eq 2 ] && [ "$(hand_value "$@")" -eq 21 ]; then
        echo "y"
    else
        echo "n"
    fi
}

# ------------------------------------------------------------------------
# Function : hand_text
# Purpose  : Builds a one-line "cards (value: X)" description of a hand,
#            for display inside Zenity dialogue text.
# ------------------------------------------------------------------------
hand_text() {
    echo "$* (value: $(hand_value "$@"))"
}

# ==============================================================================
# Function : play_round
# Purpose  : Plays a single round of Blackjack for all players against the
#            dealer, and updates the POINTS array with the outcome.
# Globals used : PLAYER_NAMES, POINTS (updated in place)
# ==============================================================================
play_round() {
    local num_players=${#PLAYER_NAMES[@]}
    local -a player_hands
    local dealer_hand=()
    local i

    build_deck
    shuffle_deck

    # Deal two opening cards to each player, then two to the dealer.
    for (( i = 0; i < num_players; i++ )); do
        deal_card; local c1="$DEALT_CARD"
        deal_card; local c2="$DEALT_CARD"
        player_hands[$i]="$c1 $c2"
    done
    deal_card; local d1="$DEALT_CARD"
    deal_card; local d2="$DEALT_CARD"
    dealer_hand=("$d1" "$d2")

    gui_info "New Round" "Dealer shows: ${dealer_hand[0]} and a hidden card"

    # --- Each player's turn -------------------------------------------
    for (( i = 0; i < num_players; i++ )); do
        read -ra hand <<< "${player_hands[$i]}"

        if [ "$(is_blackjack "${hand[@]}")" == "y" ]; then
            gui_info "${PLAYER_NAMES[$i]}'s turn" \
                "${PLAYER_NAMES[$i]}'s hand: $(hand_text "${hand[@]}")\n\n${PLAYER_NAMES[$i]} has a natural Blackjack!"
        else
            while true; do
                local value
                value=$(hand_value "${hand[@]}")
                if [ "$value" -ge 21 ]; then
                    break
                fi
                local choice
                choice=$(gui_hit_or_stand "${PLAYER_NAMES[$i]}'s hand: $(hand_text "${hand[@]}")\n\nHit or Stand?")
                if [ "$choice" == "hit" ]; then
                    deal_card
                    hand+=("$DEALT_CARD")
                    value=$(hand_value "${hand[@]}")
                    if [ "$value" -gt 21 ]; then
                        gui_info "${PLAYER_NAMES[$i]}'s turn" \
                            "${PLAYER_NAMES[$i]}'s hand: $(hand_text "${hand[@]}")\n\n${PLAYER_NAMES[$i]} busts!"
                        break
                    fi
                else
                    gui_info "${PLAYER_NAMES[$i]}'s turn" \
                        "${PLAYER_NAMES[$i]}'s hand: $(hand_text "${hand[@]}")\n\n${PLAYER_NAMES[$i]} stands on $value."
                    break
                fi
            done
        fi
        player_hands[$i]="${hand[*]}"
    done

    # --- Dealer's turn ---------------------------------------------------
    if [ "$(is_blackjack "${dealer_hand[@]}")" == "n" ]; then
        while [ "$(hand_value "${dealer_hand[@]}")" -lt 17 ]; do
            deal_card
            dealer_hand+=("$DEALT_CARD")
        done
    fi

    local dealer_value dealer_bj
    dealer_value=$(hand_value "${dealer_hand[@]}")
    dealer_bj=$(is_blackjack "${dealer_hand[@]}")

    local dealer_text="Dealer's hand: $(hand_text "${dealer_hand[@]}")"
    if [ "$dealer_value" -gt 21 ]; then
        dealer_text+="\n\nDealer busts with $dealer_value!"
    fi
    gui_info "Dealer's turn" "$dealer_text"

    # --- Work out and display each player's result ------------------------
    local results="Round Results:\n\n"
    for (( i = 0; i < num_players; i++ )); do
        read -ra hand <<< "${player_hands[$i]}"
        local p_value p_bj result
        p_value=$(hand_value "${hand[@]}")
        p_bj=$(is_blackjack "${hand[@]}")

        if [ "$p_value" -gt 21 ]; then
            result="LOSE (bust)"
        elif [ "$p_bj" == "y" ] && [ "$dealer_bj" == "y" ]; then
            result="PUSH (both Blackjack)"
        elif [ "$p_bj" == "y" ]; then
            result="WIN (Blackjack!)"
            POINTS[$i]=$(( POINTS[$i] + 1 ))
        elif [ "$dealer_bj" == "y" ]; then
            result="LOSE (dealer Blackjack)"
        elif [ "$dealer_value" -gt 21 ]; then
            result="WIN (dealer bust)"
            POINTS[$i]=$(( POINTS[$i] + 1 ))
        elif [ "$p_value" -gt "$dealer_value" ]; then
            result="WIN"
            POINTS[$i]=$(( POINTS[$i] + 1 ))
        elif [ "$p_value" -eq "$dealer_value" ]; then
            result="PUSH"
        else
            result="LOSE"
        fi

        results+="${PLAYER_NAMES[$i]}: $p_value vs Dealer $dealer_value -> $result\n"
    done

    zenity --info --title="Round Results" --width=350 --text="$results"
}

# ==============================================================================
# Function : main
# Purpose  : Entry point - sets up players and runs rounds until the user
#            chooses to stop, then shows the final points tally.
# ==============================================================================
main() {
    local num_players
    num_players=$(gui_ask_int "How many players? (1-6)" 1 6)

    PLAYER_NAMES=()
    POINTS=()
    local i
    for (( i = 0; i < num_players; i++ )); do
        PLAYER_NAMES[$i]=$(gui_ask_name "Enter name for player $((i + 1)):")
        POINTS[$i]=0
    done

    local again="y"
    while [ "$again" == "y" ]; do
        play_round
        again=$(gui_yes_no "Play another round?")
    done

    local tally="Final Points Tally:\n\n"
    for (( i = 0; i < num_players; i++ )); do
        tally+="${PLAYER_NAMES[$i]}: ${POINTS[$i]} point(s)\n"
    done
    zenity --info --title="Game Over" --text="$tally"

    exit 0
}

# Only run main automatically when the script is executed directly, not
# when it is sourced (e.g. for testing individual functions).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
