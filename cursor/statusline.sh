#!/usr/bin/env bash

payload=$(cat)

IFS=$'\t' read -r model directory input_tokens context_percentage output_tokens < <(
    jq -r '[
        .model.display_name // "Unknown model",
        .workspace.current_dir // .cwd // "",
        (.context_window.total_input_tokens // 0),
        (.context_window.used_percentage // 0),
        (.context_window.total_output_tokens // "—")
    ] | @tsv' <<< "$payload"
)

project=${directory##*/}
git_info=''

if [[ -n "$directory" ]] && GIT_OPTIONAL_LOCKS=0 git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$directory" branch --show-current 2>/dev/null)
    branch=${branch:-$(GIT_OPTIONAL_LOCKS=0 git -C "$directory" rev-parse --short HEAD 2>/dev/null)}

    if [[ -n "$(GIT_OPTIONAL_LOCKS=0 git -C "$directory" status --porcelain 2>/dev/null)" ]]; then
        git_info=" | git ${branch} *"
    else
        git_info=" | git ${branch}"
    fi
fi

printf '[%s] %s%s | input %s | context %s%% | output %s\n' \
    "$model" \
    "$project" \
    "$git_info" \
    "$input_tokens" \
    "$context_percentage" \
    "$output_tokens"
