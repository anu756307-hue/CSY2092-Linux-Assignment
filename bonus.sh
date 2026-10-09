#!/bin/bash
#
# bonus.sh (Zenity edition)
# Author: Anu
#
# PURPOSE
#   Works out monthly pay for a batch of Mercedes Benz salespeople: basic
#   salary, sales-based bonus, tax owed, and the resulting net pay. All
#   input is collected through Zenity graphical dialogue boxes (a form
#   per salesperson). Output is sorted alphabetically by name using a
#   manually written bubble sort, shown in a dialogue box, and also
#   saved to a file chosen by the user through a save dialogue.
#
# USAGE
#   $ chmod +x bonus.sh
#   $ ./bonus.sh
#   Needs a graphical session (Zenity requires X/Wayland). No arguments
#   are taken. The script first asks how many salespeople will be
#   entered (3 to 20), then shows one form per salesperson, then shows
#   the results and asks where to save them.
#
# DEPENDENCIES
#   - zenity, for every dialogue box.
#   - bc, for the currency/percentage arithmetic bash cannot do natively.
#
# DESIGN NOTES / ASSUMPTIONS
#   Two points in the brief were open to interpretation:
#     1. Bonus tiers are tiered, not cumulative - a salesperson is paid
#        the single highest bonus band their sales total qualifies for.
#     2. The brief's tax bands are applied straight to the monthly
#        gross figure (basic pay + bonus), as the brief never mentions
#        an annual conversion step.
#   Sale values are estimated from the average price given per model in
#   the brief, since the brief does not collect an exact sale price.
#   zenity --forms does not validate its own fields, so every value
#   typed into a form is re-validated after the dialogue closes; if
#   anything is invalid the whole form is redisplayed with the error
#   explained, rather than re-asking field by field.
#
# OUTPUT
#   Screen: a Zenity dialogue showing the results table, sorted by name.
#   File:   the same table, written to the path chosen in a Zenity save
#           dialogue.
# ------------------------------------------------------------------------

INT_REGEX='^[0-9]+$'
NAME_REGEX='^[A-Za-z][A-Za-z ]*$'

MODEL_NAMES=("A_Class" "B_Class" "C_Class" "E_Class" "AMG_C65")
MODEL_AVG_PRICE=(31095 33162 42537 54437 79660)
BASIC_SALARY=2000

declare -a NAMES MONTHS TOTAL_SALES GROSS_PAY TAX_PAID NET_PAY

# ------------------------------------------------------------------------
# Function : calculate_bonus
# ------------------------------------------------------------------------
calculate_bonus() {
    local sales="$1" bonus=0
    if   (( $(echo "$sales > 650000" | bc -l) )); then bonus=30000
    elif (( $(echo "$sales > 500000" | bc -l) )); then bonus=25000
    elif (( $(echo "$sales > 400000" | bc -l) )); then bonus=20000
    elif (( $(echo "$sales > 300000" | bc -l) )); then bonus=15000
    elif (( $(echo "$sales >= 200000" | bc -l) )); then bonus=10000
    fi
    echo "$bonus"
}

# ------------------------------------------------------------------------
# Function : calculate_tax
# ------------------------------------------------------------------------
calculate_tax() {
    local gross="$1" tax=0
    local allowance=12500 basic_upper=50000 higher_upper=150000
    if (( $(echo "$gross <= $allowance" | bc -l) )); then
        tax=0
    elif (( $(echo "$gross <= $basic_upper" | bc -l) )); then
        tax=$(echo "($gross - $allowance) * 0.20" | bc -l)
    elif (( $(echo "$gross <= $higher_upper" | bc -l) )); then
        tax=$(echo "(($basic_upper - $allowance) * 0.20) + (($gross - $basic_upper) * 0.40)" | bc -l)
    else
        tax=$(echo "(($basic_upper - $allowance) * 0.20) + (($higher_upper - $basic_upper) * 0.40)" | bc -l)
    fi
    printf "%.2f" "$tax"
}

# ------------------------------------------------------------------------
# Function : bubble_sort_by_name
# ------------------------------------------------------------------------
bubble_sort_by_name() {
    local n=${#NAMES[@]} i j temp
    for (( i = 0; i < n - 1; i++ )); do
        for (( j = 0; j < n - i - 1; j++ )); do
            if [[ "${NAMES[j]}" > "${NAMES[j+1]}" ]]; then
                temp="${NAMES[j]}";        NAMES[j]="${NAMES[j+1]}";        NAMES[j+1]="$temp"
                temp="${MONTHS[j]}";       MONTHS[j]="${MONTHS[j+1]}";      MONTHS[j+1]="$temp"
                temp="${TOTAL_SALES[j]}";  TOTAL_SALES[j]="${TOTAL_SALES[j+1]}"; TOTAL_SALES[j+1]="$temp"
                temp="${GROSS_PAY[j]}";    GROSS_PAY[j]="${GROSS_PAY[j+1]}";     GROSS_PAY[j+1]="$temp"
                temp="${TAX_PAID[j]}";     TAX_PAID[j]="${TAX_PAID[j+1]}";       TAX_PAID[j+1]="$temp"
                temp="${NET_PAY[j]}";      NET_PAY[j]="${NET_PAY[j+1]}";         NET_PAY[j+1]="$temp"
            fi
        done
    done
}

# ------------------------------------------------------------------------
# Function : ask_num_people
# Purpose  : Zenity entry box asking how many salespeople (3-20),
#            re-shown until a valid whole number in range is given.
# ------------------------------------------------------------------------
ask_num_people() {
    local value
    while true; do
        value=$(zenity --entry --title="Bonus Calculator" \
            --text="How many salespeople do you want to enter? (3-20)")
        [ $? -ne 0 ] && exit 0   # user clicked Cancel
        if [[ $value =~ $INT_REGEX ]] && [ "$value" -ge 3 ] && [ "$value" -le 20 ]; then
            echo "$value"
            return 0
        fi
        zenity --error --text="Please enter a whole number between 3 and 20."
    done
}

# ------------------------------------------------------------------------
# Function : ask_salesperson_form
# Purpose  : Shows one Zenity form collecting month, name, and quantity
#            sold of each of the 5 models for one salesperson. Re-shows
#            the whole form if any field fails validation.
# Arguments: $1 - salesperson number (for the dialogue title)
# Returns  : Echoes "month|name|q1|q2|q3|q4|q5"
# ------------------------------------------------------------------------
ask_salesperson_form() {
    local person_num="$1"
    local result month name q1 q2 q3 q4 q5

    while true; do
        result=$(zenity --forms \
            --title="Salesperson $person_num" \
            --text="Enter details for salesperson $person_num" \
            --add-entry="Month" \
            --add-entry="Name" \
            --add-entry="A_Class sold" \
            --add-entry="B_Class sold" \
            --add-entry="C_Class sold" \
            --add-entry="E_Class sold" \
            --add-entry="AMG_C65 sold" \
            --separator="|")
        [ $? -ne 0 ] && exit 0   # user clicked Cancel

        IFS='|' read -r month name q1 q2 q3 q4 q5 <<< "$result"

        if [[ ! $month =~ $NAME_REGEX ]]; then
            zenity --error --text="Month must contain letters only. Please try again."
            continue
        fi
        if [[ ! $name =~ $NAME_REGEX ]]; then
            zenity --error --text="Name must contain letters and spaces only. Please try again."
            continue
        fi
        local ok=1
        for q in "$q1" "$q2" "$q3" "$q4" "$q5"; do
            if [[ ! $q =~ $INT_REGEX ]]; then
                ok=0
            fi
        done
        if [ "$ok" -eq 0 ]; then
            zenity --error --text="Every quantity sold must be a whole number (0 or more). Please try again."
            continue
        fi

        echo "$month|$name|$q1|$q2|$q3|$q4|$q5"
        return 0
    done
}

# ==============================================================================
# Main program
# ==============================================================================

num_people=$(ask_num_people)

for (( p = 0; p < num_people; p++ )); do
    form_result=$(ask_salesperson_form "$((p + 1))")
    IFS='|' read -r month name q1 q2 q3 q4 q5 <<< "$form_result"

    quantities=("$q1" "$q2" "$q3" "$q4" "$q5")
    total_sales=0
    for (( m = 0; m < ${#MODEL_NAMES[@]}; m++ )); do
        model_value=$(echo "${quantities[$m]} * ${MODEL_AVG_PRICE[$m]}" | bc -l)
        total_sales=$(echo "$total_sales + $model_value" | bc -l)
    done

    bonus=$(calculate_bonus "$total_sales")
    gross=$(echo "$BASIC_SALARY + $bonus" | bc -l)
    tax=$(calculate_tax "$gross")
    net=$(echo "$gross - $tax" | bc -l)

    NAMES+=("$name")
    MONTHS+=("$month")
    TOTAL_SALES+=("$(printf "%.2f" "$total_sales")")
    GROSS_PAY+=("$(printf "%.2f" "$gross")")
    TAX_PAID+=("$tax")
    NET_PAY+=("$(printf "%.2f" "$net")")
done

bubble_sort_by_name

report=$(printf "%-18s %-8s %-14s %-12s %-10s %-10s\n" "Name" "Month" "Sales Total" "Gross Pay" "Tax" "Net Pay")
for (( i = 0; i < ${#NAMES[@]}; i++ )); do
    report+=$(printf "\n%-18s %-8s %-14s %-12s %-10s %-10s" \
        "${NAMES[$i]}" "${MONTHS[$i]}" "${TOTAL_SALES[$i]}" \
        "${GROSS_PAY[$i]}" "${TAX_PAID[$i]}" "${NET_PAY[$i]}")
done

zenity --text-info --title="Bonus Report (sorted by name)" \
    --width=640 --height=400 --font="Monospace" <<< "$report"

save_path=$(zenity --file-selection --save --confirm-overwrite \
    --title="Save results as..." --filename="salesdata.txt")
[ $? -ne 0 ] && exit 0   # user clicked Cancel on the save dialogue

echo "$report" > "$save_path"
zenity --info --text="Results saved to:\n$save_path"

exit 0
