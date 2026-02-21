#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
JSON_PATH=".screenRecord.savePath"

CUSTOM_PATH=$(jq -r "$JSON_PATH" "$CONFIG_FILE" 2>/dev/null)

RECORDING_DIR=""

if [[ -n "$CUSTOM_PATH" ]]; then
    RECORDING_DIR="$CUSTOM_PATH"
else
    RECORDING_DIR="$HOME/Videos" # Use default path
fi

echo "Recording directory: $RECORDING_DIR"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
        FULLSCREEN_FLAG=1
    fi
done

if pgrep wf-recorder > /dev/null; then
    # STOP RECORDING
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    
    # Send SIGINT (like Ctrl+C) for graceful stop - wf-recorder expects this
    pkill -INT wf-recorder

    # give wf-recorder a moment to flush/close the file
    sleep 2

    # If still running, force kill
    if pgrep wf-recorder > /dev/null; then
        pkill -9 wf-recorder
        sleep 0.5
    fi

    # find the most recent recording file
    latest_file=$(ls -1t recording_*.mp4 2>/dev/null | head -n 1)

    if [[ -n "$latest_file" ]]; then
        output="${latest_file%.mp4}_min.mp4"
        notify-send "Compressing recording" "$latest_file → $output" -a 'Recorder' & disown

        # run ffmpeg in the background
        ffmpeg -i "$latest_file" \
            -c:v libx264 -preset slow -crf 18 \
            -c:a aac -b:a 128k \
            "$output" \
            >/dev/null 2>&1 &
    fi
else
    # START RECORDING
    FILENAME="recording_$(getdate).mp4"

    if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
        notify-send "Starting recording" "$FILENAME" -a 'Recorder' & disown
        if [[ $SOUND_FLAG -eq 1 ]]; then
            wf-recorder \
                -o "$(getactivemonitor)" \
                -c h264_vaapi -d /dev/dri/renderD128 \
                -b 0 \
                -f "./$FILENAME" \
                -t \
                --audio="$(getaudiooutput)"
        else
            wf-recorder \
                -o "$(getactivemonitor)" \
                -c h264_vaapi -d /dev/dri/renderD128 \
                -b 0 \
                -f "./$FILENAME" \
                -t
        fi
    else
        # If a manual region was provided via --region, use it; otherwise run slurp as before.
        if [[ -n "$MANUAL_REGION" ]]; then
            region="$MANUAL_REGION"
        else
            if ! region="$(slurp 2>&1)"; then
                notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown
                exit 1
            fi
        fi

        notify-send "Starting recording" "$FILENAME" -a 'Recorder' & disown
        if [[ $SOUND_FLAG -eq 1 ]]; then
            wf-recorder \
                -c h264_vaapi -d /dev/dri/renderD128 \
                -b 0 \
                -f "./$FILENAME" \
                -t \
                --geometry "$region" \
                --audio="$(getaudiooutput)"
        else
            wf-recorder \
                -c h264_vaapi -d /dev/dri/renderD128 \
                -b 0 \
                -f "./$FILENAME" \
                -t \
                --geometry "$region"
        fi
    fi
fi
