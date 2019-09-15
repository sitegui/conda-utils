#!/bin/bash

ACTIVATE_CURRENT_CONDA_LAST_PWD=

function activate_current_conda {
    # This function will find the nearest 'environment.yml' file, starting from the
    # current folder and up to the root.
    # Once found, it'll activate the target environment. If the environment does not
    # exist, it'll ask for confirmation for creating it
    # Pass the flag '-q' to:
    # - only re-run the checks if the current directory changed
    # - remember negative answers to install prompt
    # This is useful as as addition to your ~/.bashrc:
    # PROMPT_COMMAND="activate_current_conda -q; $PROMPT_COMMAND"

    local QUIET TARGET_NAME CURR_PATH FILE ENV_NAME IGNORE_FILE MATCHED_LINES

    IGNORE_FILE=~/.activate_current_conda.ignore

    if [[ "$1" == -q ]]; then
        QUIET=1

        if [[ "$(pwd)" == "$ACTIVATE_CURRENT_CONDA_LAST_PWD" ]]; then
            # Do not recheck a dir while in quiet mode
            return
        fi
    fi

    TARGET_NAME=environment.yml

    # Look for file
    ACTIVATE_CURRENT_CONDA_LAST_PWD=$(pwd)
    CURR_PATH=$(pwd)
    while [[ "$CURR_PATH" != "/" && ! -e "$CURR_PATH/$TARGET_NAME" ]]; do
        CURR_PATH=$(dirname "$CURR_PATH")
    done
    FILE="$CURR_PATH/$TARGET_NAME"

    # Get environment name
    if [[ ! -r "$FILE" ]]; then
        ENV_NAME=base
    else
        ENV_NAME=$(sed -nE 's/^name:\s*(.*)/\1/p' "$FILE")
        if [[ -z "$ENV_NAME" ]]; then
            echo "Missing field 'name' in file $FILE"
            return 1
        fi
    fi

    if [[ "$CONDA_DEFAULT_ENV" == "$ENV_NAME" ]]; then
        # Already at the correct env
        return
    fi
    if [[ "$QUIET" == "1" && -r "$IGNORE_FILE" ]]; then
        MATCHED_LINES=$(grep -x "$ENV_NAME" "$IGNORE_FILE")
        if [[ ! -z "$MATCHED_LINES" ]]; then
            # The user already expressed their desire not to install it
            return
        fi
    fi

    # Activate env
    if ! conda activate "$ENV_NAME"; then
        echo "Activation failed. Maybe the environment $ENV_NAME does not exist"

        while true; do
            read -r -p "Do you want me to create it for you? (yes/no) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* )
                    echo "$ENV_NAME" >> "$IGNORE_FILE"
                    echo 'Run activate_current_conda manually to install it'
                    return
                ;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        # Create env
        conda env create -f "$FILE"
        conda activate "$ENV_NAME"

        # Remove previous ignore lines
        if [[ -r "$IGNORE_FILE" ]]; then
            grep -vx "$ENV_NAME" "$IGNORE_FILE" > "$IGNORE_FILE.temp" || true
            mv "$IGNORE_FILE.temp" "$IGNORE_FILE"
        fi
    fi

    return 0
}