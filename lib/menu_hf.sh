# menu_hf.sh - Hugging Face Models menu for ps5llm-tui
# Sourced by /usr/bin/ps5llm-tui. Uses existing UI primitives:
#   pick_one, msg, yesno, ask_text, ask_secret

HF_HELPER=/usr/local/bin/ps5llm-hf
HF_STATE=/var/lib/ps5llm-hf
HF_JOBS=$HF_STATE/jobs
MODELS_DIR=/models

menu_hf() {
    # Re-source on every entry so a long-running TUI always uses the latest
    # menu_hf.sh. (ps5llm-tui sources this file once at startup; without this,
    # a stale copy of these functions persists for the life of the TUI.)
    [ -f /usr/local/lib/menu_hf.sh ] && . /usr/local/lib/menu_hf.sh

    # Reset per-run pagination state for this TUI process.
    rm -rf "/tmp/ps5llm-hf-page-$$" 2>/dev/null || true

    # Main HF submenu
    while true; do
        # Count active jobs
        _active_jobs=$(ps5llm-hf jobs 2>/dev/null | grep -c "downloading" || true)
        _active_jobs=${_active_jobs:-0}
        _local_count=$(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | wc -l)

        sel=$(printf '%s\n' \
            "browse|Browse models  (by popularity)" \
            "community|Community  (publishers & categories)" \
            "search|Search  (by name/tag)" \
            "installed|Installed  ($_local_count local models)" \
            "jobs|Downloads  ($_active_jobs active)" \
            "auth|Authentication" \
            "back|Back" \
            | pick_one "Huggingface Models
Local: $_local_count models   Active downloads: $_active_jobs
Disk: $(df -h "$MODELS_DIR" 2>/dev/null | tail -1 | awk '{print $4}') free") || return 0

        case "$sel" in
            browse)    menu_hf_browse || true ;;
            community) menu_hf_community || true ;;
            search)    menu_hf_search || true ;;
            installed) menu_hf_installed || true ;;
            jobs)      menu_hf_jobs || true ;;
            auth)      menu_hf_auth || true ;;
            back)      return 0 ;;
        esac
    done
}

# Paginated model browser.
# $1=query $2=sort $3=limit $4=author $5=gguf_only $6=title
_hf_paginated_list() {
    _hp_query=$1
    _hp_sort=$2
    _hp_limit=$3
    _hp_author=$4
    _hp_gguf=$5
    _hp_title=$6

    _hp_state=/tmp/ps5llm-hf-page-$$
    _hp_key=$(printf '%s|%s|%s|%s|%s' \
        "$_hp_query" "$_hp_sort" "$_hp_limit" "$_hp_author" "$_hp_gguf" \
        | cksum | cut -d' ' -f1)
    _hp_dir="$_hp_state/$_hp_key"
    mkdir -p "$_hp_dir"
    _hp_cont="$_hp_dir/continue.url"
    _hp_hist="$_hp_dir/history.txt"
    _hp_pagefile="$_hp_dir/page"
    _hp_results="$_hp_dir/results.txt"

    while true; do
        _page=$(cat "$_hp_pagefile" 2>/dev/null || echo 1)
        case "$_page" in ''|*[!0-9]*) _page=1;; esac

        # Make sure the history file has at least the page-1 line (empty URL).
        [ -f "$_hp_hist" ] || printf '\n' > "$_hp_hist"

        # Fetch the requested page if we do not already have it.
        if [ ! -f "$_hp_results" ] || [ "$(cat "$_hp_pagefile" 2>/dev/null)" != "$_page" ]; then
            if [ "$_page" -eq 1 ]; then
                : > "$_hp_cont"
                # Ensure line 1 exists.
                if [ "$(wc -l < "$_hp_hist")" -lt 1 ]; then
                    printf '\n' >> "$_hp_hist"
                fi
            else
                _curline=$(sed -n "${_page}p" "$_hp_hist")
                printf '%s' "$_curline" > "$_hp_cont"
                if [ -z "$_curline" ]; then
                    # Beyond the last page - restart from the top.
                    _page=1
                    : > "$_hp_cont"
                    printf '\n' > "$_hp_hist"
                fi
            fi

            msg "Fetching page $_page..."
            if ! ps5llm-hf search-page \
                "$_hp_query" "$_hp_sort" "$_hp_limit" \
                "$_hp_author" "$_hp_gguf" "$_hp_cont" > "$_hp_results"; then
                msg "HF request failed. Check network / rate limit."
                return 1
            fi

            # Record the URL that continues from this page.
            _next=$(cat "$_hp_cont" 2>/dev/null || true)
            if [ "$(wc -l < "$_hp_hist")" -le "$_page" ]; then
                printf '%s\n' "$_next" >> "$_hp_hist"
            fi
            printf '%s' "$_page" > "$_hp_pagefile"
        fi

        _next=$(cat "$_hp_cont" 2>/dev/null || true)
        _has_next=0
        [ -n "$_next" ] && _has_next=1

        _sel=$({
            if [ "$_page" -gt 1 ]; then
                printf 'prev|<< Previous page\n'
            fi
            while IFS='|' read -r mid dl likes fmt; do
                [ -n "$mid" ] || continue
                _fmt_note=""
                [ -n "$fmt" ] && _fmt_note="  [$fmt]"
                printf '%s|%s  (%s dl, %s likes)%s\n' "$mid" "$mid" "$dl" "$likes" "$_fmt_note"
            done < "$_hp_results"
            if [ "$_has_next" -eq 1 ]; then
                printf 'next|>> Next page (more models)\n'
            fi
            printf 'back|Back\n'
        } | pick_one "$_hp_title
Page: $_page
Use Next / Previous to page through the full list.") || return 0

        case "$_sel" in
            prev)
                _page=$((_page - 1))
                printf '%s' "$_page" > "$_hp_pagefile"
                rm -f "$_hp_results"
                continue
                ;;
            next)
                _page=$((_page + 1))
                printf '%s' "$_page" > "$_hp_pagefile"
                rm -f "$_hp_results"
                continue
                ;;
            back)
                return 0
                ;;
            *)
                # The selected tag is the repository ID.
                menu_hf_model_detail "$_sel"
                ;;
        esac
    done
}

menu_hf_browse() {
    # Browse: always sorted by most downloads (consistent with Community & Search)
    _fmtsel=$(printf '%s\n' \
        "gguf|GGUF models only" \
        "all|All model formats" \
        | pick_one "Browse models  (sorted by most downloads):") || return 0
    _gguf=""
    [ "$_fmtsel" = "gguf" ] && _gguf="gguf"

    _hf_paginated_list "" "downloads" 100 "" "$_gguf" "Browse: most downloaded"
}

menu_hf_community() {
    # Community browse: category -> publisher -> models
    _cats=$(ps5llm-hf categories 2>/dev/null)
    [ -n "$_cats" ] || { msg "No categories available."; return 0; }

    _cat_sel=$(echo "$_cats" | pick_one "Community category:") || return 0
    _cat_name=$(echo "$_cat_sel" | cut -d'|' -f1)
    _cat_label=$(echo "$_cat_sel" | cut -d'|' -f2-)

    # Get publishers for this category
    _pubs=$(ps5llm-hf publishers "$_cat_name" 2>/dev/null) || {
        msg "No publishers configured for this category."; return 0
    }

    _pub_sel=$(echo "$_pubs" | pick_one "$_cat_label - select publisher:") || return 0
    _pub_id=$(echo "$_pub_sel" | cut -d'|' -f1)

    msg "Fetching models from $_pub_id..."
    _hf_paginated_list "" "downloads" 100 "$_pub_id" "" "Publisher: $_pub_id"
}

menu_hf_search() {
    # Free-text search
    _query=$(ask_text "Search models (name, tag)" "") || return 0
    [ -n "$_query" ] || return 0

    _fmtsel=$(printf '%s\n' \
        "gguf|GGUF models only" \
        "all|All model formats" \
        | pick_one "Model format filter for '$_query':") || return 0
    _gguf=""
    [ "$_fmtsel" = "gguf" ] && _gguf="gguf"

    _hf_paginated_list "$_query" "downloads" 100 "" "$_gguf" "Search: $_query"
}

menu_hf_installed() {
    # Show local models with inventory info + delete capability
    ps5llm-hf inventory-scan 2>/dev/null || true

    _models=$(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)
    [ -n "$_models" ] || { msg "No .gguf files in $MODELS_DIR."; return 0; }

    _current=$(cfg_get MODEL 2>/dev/null || echo "")

    while true; do
        _sel=$({ echo "$_models" | while read -r m; do
            _mark=" "
            [ "$m" = "$_current" ] && _mark="*"
            _size=$(human_size "$(wc -c < "$m" 2>/dev/null || echo 0)")
            _quant=$(detect_quant "$m" 2>/dev/null || echo "?")
            printf '%s|[%s] %s  (%s, %s)\n' "$m" "$_mark" "$(basename "$m")" "$_size" "$_quant"
        done; printf 'back|Back\n'; } | pick_one "Local models (* = loaded)
Select a model to manage.") || return 0

        # Check if user selected Back
        [ "$_sel" = "back" ] && return 0

        # Show actions for selected model
        _action=$(printf '%s\n' \
            "info|Show details" \
            "delete|Delete this model" \
            "back|Back to list" \
            | pick_one "$(basename "$_sel")") || return 0

        case "$_action" in
            info)
                _size=$(human_size "$(wc -c < "$_sel" 2>/dev/null || echo 0)")
                _quant=$(detect_quant "$_sel" 2>/dev/null || echo "?")
                _fmt=$(detect_format "$_sel" 2>/dev/null || echo "?")
                _inv=$(grep -F "$_sel" "$HF_STATE/inventory.tsv" 2>/dev/null || true)
                msg "Model: $(basename "$_sel")
Path: $_sel
Size: $_size
Quant: $_quant
Format: $_fmt
Status: $([ "$_sel" = "$_current" ] && echo "LOADED" || echo "not loaded")

Inventory record:
${_inv:-none}"
                ;;
            delete)
                if [ "$_sel" = "$_current" ]; then
                    msg "WARNING: This model is currently LOADED.
You must unload it (stop the server) before deleting.
Stop the server first, then delete."
                    continue
                fi
                if ! yesno "DELETE this model?

$_sel
$(human_size "$(wc -c < "$_sel" 2>/dev/null || echo 0)")

This permanently removes the file.
This cannot be undone."; then
                    continue
                fi
                _del_size=$(wc -c < "$_sel" 2>/dev/null || echo 0)
                if rm -f "$_sel" 2>/dev/null; then
                    # Remove from inventory
                    grep -vF "$_sel" "$HF_STATE/inventory.tsv" > "$HF_STATE/inventory.tsv.tmp" 2>/dev/null || true
                    mv "$HF_STATE/inventory.tsv.tmp" "$HF_STATE/inventory.tsv" 2>/dev/null || true
                    # Remove empty parent directories created for repo downloads.
                    _parent=$(dirname "$_sel")
                    while [ "$_parent" != "$MODELS_DIR" ] && [ "$_parent" != "/" ]; do
                        if [ -d "$_parent" ] && [ -z "$(ls -A "$_parent" 2>/dev/null)" ]; then
                            rmdir "$_parent" 2>/dev/null || true
                            _parent=$(dirname "$_parent")
                        else
                            break
                        fi
                    done
                    msg "Deleted: $(basename "$_sel")
Freed: $(human_size "$_del_size")"
                    # Refresh model list
                    _models=$(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)
                    [ -n "$_models" ] || return 0
                else
                    msg "FAILED to delete: $_sel
Check permissions."
                fi
                ;;
            back) continue ;;
        esac
    done
}

menu_hf_jobs() {
    # Show download jobs
    while true; do
        _jobs=$(ps5llm-hf jobs 2>/dev/null || true)
        _sel=$({
            if [ -n "$_jobs" ]; then
                echo "$_jobs" | while IFS='|' read -r jid jrepo jstatus; do
                    printf '%s|%s  [%s]\n' "$jid" "$jrepo" "$jstatus"
                done
            fi
            printf 'refresh|Refresh list\n'
            printf 'back|Back\n'
        } | pick_one "Download jobs") || return 0

        case "$_sel" in
            refresh) continue ;;
            back) return 0 ;;
            *)
                menu_hf_job_detail "$_sel" || true
                ;;
        esac
    done
}

menu_hf_job_detail() {
    # $1=job_id -> show detailed status
    _job=$1
    while true; do
        _info=$(ps5llm-hf status "$_job" 2>/dev/null || true)
        _status=$(echo "$_info" | grep '^status=' | cut -d= -f2-)
        _log_file="$HF_JOBS/$_job.log"
        _tail=""
        [ -f "$_log_file" ] && _tail=$(tail -10 "$_log_file" 2>/dev/null | tr '\r' '\n' | tail -5)
        _repo=$(echo "$_info" | grep '^repo=' | cut -d= -f2-)

        # Build menu based on status
        case "$_status" in
            downloading|starting)
                _sel=$(printf '%s\n' \
                    "show|Show status + log" \
                    "stop|Stop download" \
                    "back|Back" \
                    | pick_one "Job: $_job  [$_status]") || return 0
                ;;
            *)
                _sel=$(printf '%s\n' \
                    "show|Show status + log" \
                    "remove|Remove from list" \
                    "back|Back" \
                    | pick_one "Job: $_job  [$_status]") || return 0
                ;;
        esac

        case "$_sel" in
            show)
                msg "Job: $_job
$_info

--- recent log ---
${_tail:-no log output yet}"
                ;;
            stop)
                if yesno "Stop download for $_repo?
The download process will be killed.
You can then delete the partial files."; then
                    ps5llm-hf cancel "$_job" 2>/dev/null || true
                    msg "Download stopped."
                    # Offer to delete partial files
                    _dest=$(grep '^dest=' "$HF_JOBS/$_job" 2>/dev/null | cut -d= -f2-)
                    if [ -n "$_dest" ] && [ -d "$_dest" ]; then
                        if yesno "Delete partial files in:
$_dest/

This removes the incomplete download.
The job will be removed from the list."; then
                            rm -rf "$_dest"
                            msg "Partial files deleted."
                        fi
                    fi
                    # Remove from job list
                    ps5llm-hf remove "$_job" 2>/dev/null || true
                    msg "Job removed from list."
                    return 0
                fi
                ;;
            remove)
                if yesno "Remove this job from the download list?

$_repo  [$_status]

This only removes it from the list.
The model files (if downloaded) are NOT deleted."; then
                    ps5llm-hf remove "$_job" 2>/dev/null || true
                    msg "Job removed from list."
                    return 0
                fi
                ;;
            back)
                return 0
                ;;
        esac
    done
}

menu_hf_model_detail() {
    # $1=repo_id -> show files, allow download selection
    _repo=$1

    msg "Fetching file list for: $_repo
(This queries the Hugging Face API...)"

    _files=$(ps5llm-hf files "$_repo" 2>/dev/null) || {
        msg "Failed to fetch file list for $_repo.
Possible causes:
  - Network issue
  - Repository does not exist
  - Repository is gated (needs authentication)
  - Rate limited"; return 1
    }

    [ -n "$_files" ] || { msg "No files found in $_repo"; return 0; }

    # Separate model files from config files
    _model_files=$(echo "$_files" | grep -E '\.(gguf|safetensors|bin|pt)\|' || true)

    # If no model files, show all
    [ -n "$_model_files" ] || _model_files="$_files"

    # Show file selection
    _total_size=$(echo "$_model_files" | awk -F'|' '{s+=$2} END {print s+0}')
    _free=$(disk_free_bytes 2>/dev/null || echo 0)
    _free_hr=$(human_size "${_free:-0}")
    _total_hr=$(human_size "$_total_size")

    # Build selection list (use full path as tag - paths never contain |)
    _sel=$({
        printf 'all|Download ALL model files  (%s)\n' "$_total_hr"
        echo "$_model_files" | while IFS='|' read -r fpath fsize; do
            _quant=$(detect_quant "$fpath")
            _fmt=$(detect_format "$fpath")
            _size_hr=$(human_size "$fsize")
            printf '%s|%s  (%s) [%s %s]\n' "$fpath" "$(basename "$fpath")" "$_size_hr" "$_quant" "$_fmt"
        done
    } | pick_one "Files in $_repo
Model files: $(_count_lines "$_model_files")
Estimated total: $_total_hr
Disk free: $_free_hr

Select a file, or ALL model files:") || return 0

    # Destination: one predictable directory per repository.
    _dest="$MODELS_DIR/$_repo"
    _existing_note=""
    [ -d "$_dest" ] && _existing_note="\nNote: destination already exists: $_dest"

    if [ "$_sel" = "all" ]; then
        _what="ALL model files"
        _size_hr="$_total_hr"
    else
        _what="$_sel"
        _size_hr=$(human_size "$(echo "$_model_files" | grep -F "$_sel" | cut -d'|' -f2)")
    fi

    # Confirm download
    if ! yesno "Download from Hugging Face?

Repository: $_repo
File: $_what
Size: $_size_hr
Destination: $_dest/
$_existing_note

This starts a BACKGROUND download.
The TUI stays responsive.
Check 'Downloads' in this menu for progress."; then
        return 0
    fi

    # Start download
    if [ "$_sel" = "all" ]; then
        _job_id=$(ps5llm-hf download "$_repo" "$_dest" --all 2>/dev/null) || {
            msg "Failed to start download. Check network and try again."; return 1
        }
    else
        _job_id=$(ps5llm-hf download "$_repo" "$_dest" "$_sel" 2>/dev/null) || {
            msg "Failed to start download. Check network and try again."; return 1
        }
    fi

    msg "Download started!

Job: $_job_id
Repo: $_repo
File: $_what
Dest: $_dest/

Check progress in: Hugging Face -> Downloads
The download continues even if you leave this menu."
}

menu_hf_auth() {
    # Authentication management
    _status=$(ps5llm-hf auth-status 2>/dev/null)
    sel=$(printf '%s\n' \
        "status|Status: $_status" \
        "set|Set / update token" \
        "clear|Clear stored token" \
        "back|Back" \
        | pick_one "Hugging Face Authentication") || return 0

    case "$sel" in
        status) msg "Auth status: $_status

Public repos work without a token.
A token is needed for:
  - Gated repositories (accept license first on huggingface.co)
  - Private repositories
  - Higher rate limits

Get a token: https://huggingface.co/settings/tokens" ;;
        set)
            _tok=$(ask_secret "Hugging Face token (hf_...)") || return 0
            [ -n "$_tok" ] || { msg "Empty token - cancelled."; return 0; }
            ps5llm-hf auth-set "$_tok" 2>/dev/null
            msg "Token stored."
            ;;
        clear)
            rm -f "$HF_STATE/hf_token" 2>/dev/null || true
            msg "Token cleared."
            ;;
    esac
}

# Helper: count lines
_count_lines() {
    printf '%s' "$1" | grep -c . 2>/dev/null || echo 0
}

# Helper: human-readable size (local copy for TUI context)
human_size() {
    _b="$1"
    case "$_b" in
        ''|*[!0-9]*) echo "unknown";;
        *) awk -v b="$_b" 'BEGIN{
            if(b>=1073741824) printf "%.1f GB", b/1073741824
            else if(b>=1048576) printf "%.0f MB", b/1048576
            else if(b>=1024) printf "%.0f KB", b/1024
            else printf "%d B", b
        }';;
    esac
}

# Helper: detect quantization (local copy for TUI context)
detect_quant() {
    _f="$(basename "$1")"
    _f=$(echo "$_f" | tr 'A-Z' 'a-z')
    case "$_f" in
        *q8_0*) echo "Q8_0" ;;
        *q6_k*) echo "Q6_K" ;;
        *q5_k_m*) echo "Q5_K_M" ;;
        *q5_k_s*) echo "Q5_K_S" ;;
        *q4_k_m*) echo "Q4_K_M" ;;
        *q4_k_s*) echo "Q4_K_S" ;;
        *q4_0*) echo "Q4_0" ;;
        *q4_1*) echo "Q4_1" ;;
        *q3_k_m*) echo "Q3_K_M" ;;
        *q3_k_s*) echo "Q3_K_S" ;;
        *q3_k_l*) echo "Q3_K_L" ;;
        *q2_k*) echo "Q2_K" ;;
        *iq8_xxs*) echo "IQ8_XXS" ;;
        *iq8_xs*) echo "IQ8_XS" ;;
        *iq6_xxs*) echo "IQ6_XXS" ;;
        *iq6_xs*) echo "IQ6_XS" ;;
        *iq5_xxs*) echo "IQ5_XXS" ;;
        *iq5_xs*) echo "IQ5_XS" ;;
        *iq4_nl*) echo "IQ4_NL" ;;
        *iq4_xs*) echo "IQ4_XS" ;;
        *iq3_xxs*) echo "IQ3_XXS" ;;
        *iq3_xs*) echo "IQ3_XS" ;;
        *iq2_xxs*) echo "IQ2_XXS" ;;
        *iq2_xs*) echo "IQ2_XS" ;;
        *iq2_s*) echo "IQ2_S" ;;
        *iq2_m*) echo "IQ2_M" ;;
        *iq1_s*) echo "IQ1_S" ;;
        *f16*|*fp16*) echo "F16" ;;
        *bf16*) echo "BF16" ;;
        *f32*|*fp32*) echo "F32" ;;
        *gptq*) echo "GPTQ" ;;
        *awq*) echo "AWQ" ;;
        *exl2*) echo "EXL2" ;;
        *safetensors*) echo "Safetensors" ;;
        *gguf*) echo "GGUF" ;;
        *) echo "?" ;;
    esac
}

# Helper: detect format
detect_format() {
    case "$1" in
        *.gguf) echo "GGUF" ;;
        *.safetensors) echo "Safetensors" ;;
        *.bin|*.pt) echo "PyTorch" ;;
        *) echo "" ;;
    esac
}

# Helper: disk free
disk_free_bytes() {
    df -B1 "$MODELS_DIR" 2>/dev/null | tail -1 | awk '{print $4}'
}