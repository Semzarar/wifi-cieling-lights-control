#!/usr/bin/env bash
##
## Author : @semzarar
## Lights control menu using yad + tinytuya
##

LIGHTS_PY="/home/semzarar/lights.py"
PRESETS_DIR="$HOME/.config/lights"
PRESETS_FILE="$PRESETS_DIR/presets.json"

#make sure presets file exists
mkdir -p "$PRESETS_DIR"
[ -f "$PRESETS_FILE" ] || echo '{}' > "$PRESETS_FILE"

#execute a preset
run_preset() {
    local name="$1"
    #Get commands array for this preset and run each in parallel
    local count=$(python3 -c "
import json
with open('$PRESETS_FILE') as f:
    p = json.load(f)
cmds = p.get('$name', [])
print(len(cmds))
for c in cmds:
    print(c)
")
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        eval "$LIGHTS_PY $line" &
    done <<< "$(echo "$count" | tail -n +2)"
    wait
    notify-send "Lights" "Preset: $name"
}

#build a command string manually
build_command() {
    #pick target
    target=$(yad --list \
        --title "Add Command - Target" \
        --text "Which lights?" \
        --column "Target" --column "Description" \
        "ALL"   "All lights" \
        "MULTI" "Pick multiple..." \
        "BL"    "Back Left" \
        "BR"    "Back Right" \
        "FL"    "Front Left" \
        "FR"    "Front Right" \
        --print-column=1 2>/dev/null)
    [ -z "$target" ] && return 1
    target=$(echo "$target" | tr -d '|')

    #multi selection
    if [ "$target" = "MULTI" ]; then
        multi=$(yad --list \
            --checklist \
            --title "Select Lights" \
            --text "Which lights to control?" \
            --column "✓" --column "Name" --column "Location" \
            TRUE  "BL" "Back Left" \
            TRUE  "BR" "Back Right" \
            TRUE  "FL" "Front Left" \
            TRUE  "FR" "Front Right" \
            --separator=" " \
            --print-column=2 2>/dev/null)
        [ -z "$multi" ] && return 1
        targets="$multi"
    else
        targets="$target"
    fi

    #pick mode
    mode=$(yad --list \
        --title "Add Command - Mode" \
        --column "Mode" \
        "on" \
        "off" \
        "white" \
        "colour" \
        "bright" \
        "dim" \
        "red" \
        "green" \
        "blue" \
        "disco" \
        --print-column=1 2>/dev/null)
    [ -z "$mode" ] && return 1
    mode=$(echo "$mode" | tr -d '|')

    #get mode specific args
    case "$mode" in
        white)
            result=$(yad --form \
                --title "White Settings" \
                --field="Brightness (10-1000):NUM" 1000 \
                --field="Warmth - Cool(0) to Warm(1000):NUM" 500 \
                --separator="|" 2>/dev/null)
            [ -z "$result" ] && return 1
            b=$(echo $result | cut -d'|' -f1 | cut -d'.' -f1)
            w=$(echo $result | cut -d'|' -f2 | cut -d'.' -f1)
            for t in $targets; do echo "white $t $b $w"; done
            ;;
        colour)
            result=$(yad --form \
                --title "Colour Settings" \
                --field="Red (0-255):NUM" 255 \
                --field="Green (0-255):NUM" 0 \
                --field="Blue (0-255):NUM" 0 \
                --field="Brightness (10-1000):NUM" 1000 \
                --separator="|" 2>/dev/null)
            [ -z "$result" ] && return 1
            r=$(echo $result | cut -d'|' -f1 | cut -d'.' -f1)
            g=$(echo $result | cut -d'|' -f2 | cut -d'.' -f1)
            b=$(echo $result | cut -d'|' -f3 | cut -d'.' -f1)
            br=$(echo $result | cut -d'|' -f4 | cut -d'.' -f1)
            for t in $targets; do echo "colour $t $r $g $b $br"; done
            ;;
        *)
            for t in $targets; do echo "$mode $t"; done
            ;;
    esac
    return 0
}

#create a new preset 
create_preset() {
    #get preset name
    name=$(yad --entry \
        --title "New Preset" \
        --text "Enter preset name:" \
        2>/dev/null)
    [ -z "$name" ] && return

    commands=()

    while true; do
        #show current commands and options
        current=""
        for cmd in "${commands[@]}"; do
            current="$current• $cmd\n"
        done
        [ -z "$current" ] && current="(no commands yet)\n"

        action=$(yad --list \
            --title "Preset: $name" \
            --text "Commands:\n${current}" \
            --column "Action" \
            "➕ Add Command" \
            "✅ Save Preset" \
            "❌ Cancel" \
            --print-column=1 2>/dev/null)
        action=$(echo "$action" | tr -d '|')

        case "$action" in
            "➕ Add Command"*)
                cmd=$(build_command)
                if [ $? -eq 0 ] && [ -n "$cmd" ]; then
                    while IFS= read -r line; do
                        [ -n "$line" ] && commands+=("$line")
                    done <<< "$cmd"
                fi
                ;;
            "✅ Save Preset"*)
                if [ ${#commands[@]} -eq 0 ]; then
                    yad --info --text "Add at least one command first!" 2>/dev/null
                    continue
                fi
                #save to json using helper
                python3 /home/semzarar/.config/lights/preset_save.py "$PRESETS_FILE" "$name" "${commands[@]}"
                notify-send "Lights" "Preset '$name' saved!"
                return
                ;;
            *)
                return
                ;;
        esac
    done
}

#delete a preset
delete_preset() {
    presets=$(python3 -c "
import json
with open('$PRESETS_FILE') as f:
    p = json.load(f)
for k in p.keys():
    print(k)
" 2>/dev/null)
    [ -z "$presets" ] && yad --info --text "No presets to delete." 2>/dev/null && return

    name=$(echo "$presets" | yad --list \
        --title "Delete Preset" \
        --text "Select preset to delete:" \
        --column "Preset" \
        --print-column=1 2>/dev/null)
    [ -z "$name" ] && return
    name=$(echo "$name" | tr -d '|')

    confirm=$(yad --list \
        --title "Confirm" \
        --text "Delete '$name'?" \
        --column "Option" \
        "Yes" "No" \
        --print-column=1 2>/dev/null)
    confirm=$(echo "$confirm" | tr -d '|')
    [ "$confirm" != "Yes" ] && return

    python3 -c "
import json
with open('$PRESETS_FILE') as f:
    p = json.load(f)
p.pop('$name', None)
with open('$PRESETS_FILE', 'w') as f:
    json.dump(p, f, indent=2)
"
    notify-send "Lights" "Preset '$name' deleted."
}

#presets menu
presets_menu() {
    while true; do
        #build list of existing presets
        preset_list=$(python3 -c "
import json
with open('$PRESETS_FILE') as f:
    p = json.load(f)
for k in p.keys():
    print(k)
" 2>/dev/null)

        options="➕ New Preset\n🗑️ Delete Preset"
        [ -n "$preset_list" ] && options="$options\n$preset_list"

        chosen=$(echo -e "$options" | yad --list \
            --title "Presets" \
            --text "Select a preset or action:" \
            --column "Preset" \
            --print-column=1 2>/dev/null)
        [ -z "$chosen" ] && return
        chosen=$(echo "$chosen" | tr -d '|')

        case "$chosen" in
            "➕ New Preset"*) create_preset ;;
            "🗑️ Delete Preset"*) delete_preset ;;
            *) run_preset "$chosen" ; return ;;
        esac
    done
}

#white/warmth control
white_mode() {
    local target=$1
    result=$(yad --form \
        --title "White Mode" \
        --text "Adjust white light" \
        --field="Brightness (10-1000):NUM" 1000 \
        --field="Warmth - Cool(0) to Warm(1000):NUM" 500 \
        --separator="|" 2>/dev/null)
    [ -z "$result" ] && exit 0
    brightness=$(echo $result | cut -d'|' -f1 | cut -d'.' -f1)
    warmth=$(echo $result | cut -d'|' -f2 | cut -d'.' -f1)
    $LIGHTS_PY white "$target" "$brightness" "$warmth"
    notify-send "Lights" "White: brightness $brightness, warmth $warmth"
}

#colour control
colour_mode() {
    local target=$1
    result=$(yad --form \
        --title "Colour Mode" \
        --text "Adjust colour" \
        --field="Red (0-255):NUM" 255 \
        --field="Green (0-255):NUM" 0 \
        --field="Blue (0-255):NUM" 0 \
        --field="Brightness (10-1000):NUM" 1000 \
        --separator="|" 2>/dev/null)
    [ -z "$result" ] && exit 0
    r=$(echo $result | cut -d'|' -f1 | cut -d'.' -f1)
    g=$(echo $result | cut -d'|' -f2 | cut -d'.' -f1)
    b=$(echo $result | cut -d'|' -f3 | cut -d'.' -f1)
    brightness=$(echo $result | cut -d'|' -f4 | cut -d'.' -f1)
    $LIGHTS_PY colour "$target" "$r" "$g" "$b" "$brightness"
    notify-send "Lights" "Colour: RGB($r,$g,$b) brightness $brightness"
}

# on off
onoff_mode() {
    local target=$1
    chosen=$(yad --list \
        --title "On / Off" \
        --text "Toggle lights" \
        --column "Action" \
        "💡 Turn On" \
        "🌑 Turn Off" \
        --print-column=1 2>/dev/null)
    [ -z "$chosen" ] && exit 0
    case "$chosen" in
        "💡 Turn On"*)
            $LIGHTS_PY on "$target"
            notify-send "Lights" "On"
            ;;
        "🌑 Turn Off"*)
            $LIGHTS_PY off "$target"
            notify-send "Lights" "Off"
            ;;
    esac
}

#sub menu
sub_menu() {
    local target=$1
    chosen=$(yad --list \
        --title "Lights" \
        --text "Mode" \
        --column "Mode" \
        "☀️ White / Warmth" \
        "🎨 Colour" \
        "💡 On / Off" \
        --print-column=1 2>/dev/null)
    [ -z "$chosen" ] && exit 0
    case "$chosen" in
        "☀️ White / Warmth"*) white_mode "$target" ;;
        "🎨 Colour"*)         colour_mode "$target" ;;
        "💡 On / Off"*)       onoff_mode "$target" ;;
    esac
}

#main menu
#build dynamic preset entries
preset_entries=$(python3 -c "
import json
with open('$PRESETS_FILE') as f:
    p = json.load(f)
for k in p.keys():
    print('⭐ ' + k)
" 2>/dev/null)

main_options="🏠 All Lights\n💡 Single Light\n🎛️ Multi Light\n📋 Presets"
[ -n "$preset_entries" ] && main_options="$main_options\n$preset_entries"

chosen=$(echo -e "$main_options" | yad --list \
    --title "Lights" \
    --text "Control lighting" \
    --column "Option" \
    --print-column=1 2>/dev/null)

[ -z "$chosen" ] && exit 0
chosen=$(echo "$chosen" | tr -d '|')

case "$chosen" in
    "🏠 All Lights"*)
        sub_menu "ALL"
        ;;
    "💡 Single Light"*)
        light=$(yad --list \
            --title "Select Light" \
            --column "Name" --column "Location" \
            "BL" "Back Left" \
            "BR" "Back Right" \
            "FL" "Front Left" \
            "FR" "Front Right" \
            --print-column=1 2>/dev/null)
        [ -z "$light" ] && exit 0
        sub_menu "$(echo $light | tr -d '|')"
        ;;
    "🎛️ Multi Light"*)
        lights=$(yad --list \
            --checklist \
            --title "Select Lights" \
            --text "Which lights to control?" \
            --column "✓" --column "Name" --column "Location" \
            TRUE "BL" "Back Left" \
            TRUE "BR" "Back Right" \
            TRUE "FL" "Front Left" \
            TRUE "FR" "Front Right" \
            --separator=" " \
            --print-column=2 2>/dev/null)
        [ -z "$lights" ] && exit 0
        #get the mode once, apply to all selected in parallel
        mode_chosen=$(yad --list \
            --title "Lights" \
            --text "Mode" \
            --column "Mode" \
            "☀️ White / Warmth" \
            "🎨 Colour" \
            "💡 On / Off" \
            --print-column=1 2>/dev/null)
        [ -z "$mode_chosen" ] && exit 0
        for t in $lights; do
            case "$mode_chosen" in
                "☀️ White / Warmth"*) white_mode "$t" & ;;
                "🎨 Colour"*)         colour_mode "$t" & ;;
                "💡 On / Off"*)       onoff_mode "$t" & ;;
            esac
        done
        wait
        ;;
    "📋 Presets"*)
        presets_menu
        ;;
    "⭐ "*)
        #direct preset execution from main menu
        preset_name="${chosen#⭐ }"
        run_preset "$preset_name"
        ;;
esac
