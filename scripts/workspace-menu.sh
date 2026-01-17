#!/usr/bin/env bash
# =============================================================================
# Kitty Workspace Menu - Config-driven Claude Code launcher
# =============================================================================
#
# USAGE:
#   ~/.config/kitty/scripts/workspace-menu.sh
#   Or via keybinding: ⌘⇧M (configured in kitty.conf)
#
# CONFIGURATION:
#   ~/.config/kitty/workspaces.yaml
#
# DEPENDENCIES:
#   - gum (brew install gum)
#   - yq (brew install yq)
#   - kitty with remote control enabled (allow_remote_control yes)
#
# NAVIGATION:
#   - Arrow keys / j/k to navigate
#   - Enter to select
#   - Esc or Ctrl-C to cancel/go back
#   - "← Back" option returns to previous level
#
# =============================================================================
set -euo pipefail

CFG="${HOME}/.config/kitty/workspaces.yaml"
RECENT_PRDS_FILE="${HOME}/.config/kitty/.recent-prds"

# ---------- UI helpers ----------

error() {
  gum style \
    --foreground 196 \
    --border-foreground 196 \
    --border rounded \
    --padding "0 1" \
    --margin "1 0" \
    "ERROR: $1"
  sleep 2
}

info() {
  gum style \
    --foreground 226 \
    --padding "0 1" \
    "$1"
}

header() {
  gum style \
    --foreground 39 \
    --bold \
    --padding "0 1" \
    "$1"
}

# ---------- prerequisites ----------

check_dependencies() {
  local missing=()
  for cmd in gum yq kitty; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing dependencies: ${missing[*]}"
    echo "Install with: brew install ${missing[*]}"
    exit 1
  fi
}

check_config() {
  if [[ ! -f "$CFG" ]]; then
    error "Config file not found: $CFG"
    exit 1
  fi

  # Validate required keys exist
  local required_keys=(".repo_roots" ".colors" ".workspaces")
  for key in "${required_keys[@]}"; do
    if [[ "$(yq -e "$key" "$CFG" 2>/dev/null)" == "null" ]]; then
      error "Missing required key in config: $key"
      exit 1
    fi
  done
}

check_dependencies
check_config

# ---------- YAML helpers ----------

yaml() {
  yq -r "$1" "$CFG" 2>/dev/null || echo ""
}

yaml_array() {
  # Returns array items one per line, handles empty arrays
  local result
  result="$(yq -r "$1 // [] | .[]" "$CFG" 2>/dev/null)" || true
  echo "$result"
}

resolve_path() {
  local raw="$1"
  eval "echo \"$raw\""
}

# ---------- menu helpers ----------

pick_single() {
  # Single selection menu - returns selected item or empty on cancel
  echo "DEBUG pick_single: args=$*" >&2
  gum choose \
    --cursor-prefix "➜ " \
    --selected-prefix "✓ " \
    --height 15 \
    "$@"
  local rc=$?
  echo "DEBUG pick_single: exit code=$rc" >&2
  return $rc
}

prompt_input() {
  # Input prompt with cancel support
  gum input --prompt "$1" 2>/dev/null || echo ""
}

# ---------- validation ----------

validate_directory() {
  local dir="$1"
  local name="$2"
  if [[ ! -d "$dir" ]]; then
    error "$name directory does not exist: $dir"
    return 1
  fi
  return 0
}

# ---------- recent PRDs ----------

save_recent_prd() {
  local prd="$1"
  local module="$2"

  # Create file if doesn't exist
  touch "$RECENT_PRDS_FILE"

  # Add to top, remove duplicates, keep last 10
  local entry="$module:$prd"
  {
    echo "$entry"
    grep -v "^${entry}$" "$RECENT_PRDS_FILE" 2>/dev/null || true
  } | head -10 > "${RECENT_PRDS_FILE}.tmp"
  mv "${RECENT_PRDS_FILE}.tmp" "$RECENT_PRDS_FILE"
}

get_recent_prds() {
  local module="$1"
  if [[ -f "$RECENT_PRDS_FILE" ]]; then
    grep "^${module}:" "$RECENT_PRDS_FILE" 2>/dev/null | cut -d: -f2- | head -5 || true
  fi
}

# ---------- context display ----------

print_context() {
  local workspace="$1"
  local module="${2:-}"
  local mode="${3:-}"
  local prd="${4:-}"
  local cwd="$5"

  echo ""
  gum style \
    --border rounded \
    --border-foreground 240 \
    --padding "0 1" \
    --margin "0 0 1 0" \
    "$(cat <<EOF
Workspace: $workspace
$([ -n "$module" ] && echo "Module:    $module")
$([ -n "$mode" ] && echo "Mode:      $mode")
$([ -n "$prd" ] && echo "PRD:       $prd")
Directory: $cwd
EOF
)"
  echo ""
}

# ---------- launch ----------

launch_window() {
  local title="$1"
  local cwd="$2"
  local bg="$3"
  local fg="$4"
  local cur="$5"
  local command="$6"
  local context="$7"

  # Validate directory
  if ! validate_directory "$cwd" "Working"; then
    return 1
  fi

  # Create a wrapper script that prints context then runs command
  local wrapper_script
  wrapper_script=$(cat <<WRAPPER
#!/usr/bin/env bash
cat <<'CONTEXT'
$context
CONTEXT
exec $command
WRAPPER
)

  # Launch new OS window with the wrapper
  kitty @ launch \
    --type=tab \
    --cwd "$cwd" \
    --title "$title" \
    bash -lc "$wrapper_script" >/dev/null 2>&1

  # Small delay to ensure window is created
  sleep 0.1

  # Style the most recently created window
  kitty @ set-colors --match "title:$title" \
    background="$bg" \
    foreground="$fg" \
    cursor="$cur" >/dev/null 2>&1 || true

  return 0
}

# ---------- RPC JSON menu ----------

# RPC method definitions organized by category
declare -A RPC_CATEGORIES
RPC_CATEGORIES=(
  ["1. Core System Methods"]="SUBMENU"
  ["2. WiFi Methods"]="WiFi.GetStatus|WiFi.GetConfig|WiFi.SetConfig"
  ["3. MQTT Methods"]="MQTT.GetStatus|MQTT.GetConfig|MQTT.SetConfig"
  ["4. Switch/Relay Methods"]="Switch.GetStatus|Switch.GetConfig|Switch.SetConfig|Switch.Set|Switch.Toggle|Switch.ResetCounters"
  ["5. Light/Dimmer Methods"]="Light.GetStatus|Light.GetConfig|Light.SetConfig|Light.Set|Light.Toggle|Light.DimUp|Light.DimDown|Light.DimStop|Light.Calibrate"
  ["6. Cover/Shutter Methods"]="Cover.GetStatus|Cover.GetConfig|Cover.SetConfig|Cover.Open|Cover.Close|Cover.Stop|Cover.GoToPosition|Cover.Calibrate"
  ["7. Input Methods"]="Input.GetStatus|Input.GetConfig|Input.SetConfig"
  ["8. Temperature/Humidity Methods"]="Temperature.GetStatus|Temperature.SetConfig|Humidity.GetStatus|Humidity.SetConfig"
  ["9. Energy Meter Methods"]="EM.GetStatus|EM.SetConfig|EMData.GetStatus|EMData.ResetCounters"
  ["10. JACK-Specific Methods"]="Jack.GetCapabilities|Jack.GrantEntitlement|Jack.GetBootLog|Led.Test|Led.SetColor|Led.GetStatus|Jack.WaterTank.SetConfig|Jack.WaterTank.GetConfig|Jack.WaterTank.GetStatus|Jack.RuuviScan|Jack.RuuviRegister|Jack.RuuviDelete|Jack.RuuviList|Jack.RuuviGetStatus|Time.GetStatus|Device.Identify"
)

# Shelly core system methods
SHELLY_SYSTEM_METHODS="Shelly.GetDeviceInfo|Shelly.GetStatus|Shelly.GetConfig|Shelly.ListMethods|Shelly.Reboot|Shelly.FactoryReset|Shelly.CheckForUpdate|Shelly.Update|Shelly.GetComponents|Shelly.ListProfiles|Shelly.SetProfile|Shelly.SetAuth|Shelly.DetectLocation"

# JACK core system methods
JACK_SYSTEM_METHODS="Jack.GetDeviceInfo|Jack.GetStatus|Jack.GetConfig|Jack.ListMethods|Jack.Reboot|Jack.FactoryReset"

execute_rpc_method() {
  local method="$1"
  local ip="$2"
  local bg="$3"
  local fg="$4"
  local cur="$5"

  local title="RPC: $method @ $ip"

  # Create a temporary script to avoid escaping issues
  local tmp_script
  tmp_script=$(mktemp)
  cat > "$tmp_script" << 'SCRIPT_EOF'
#!/bin/bash
METHOD="$1"
IP="$2"

echo '═══════════════════════════════════════════════════════════════'
echo "RPC Method: $METHOD"
echo "Target IP:  $IP"
echo "Via:        ssh barndo"
echo '═══════════════════════════════════════════════════════════════'
echo ''

# Build JSON payload
JSON_PAYLOAD="{\"id\":1,\"method\":\"$METHOD\"}"

# Execute via SSH to barndo
ssh barndo "curl -s -X POST http://$IP/rpc -H 'Content-Type: application/json' -d '$JSON_PAYLOAD'" | python3 -m json.tool 2>/dev/null || cat

echo ''
echo '───────────────────────────────────────────────────────────────'
echo 'Press Enter to close...'
read
SCRIPT_EOF
  chmod +x "$tmp_script"

  # Launch new Kitty OS window running the script
  kitty @ launch \
    --type=os-window \
    --title "$title" \
    bash -lc "$tmp_script '$method' '$ip'; rm -f '$tmp_script'"

  sleep 0.1
  kitty @ set-colors --match "title:$title" \
    background="$bg" foreground="$fg" cursor="$cur" 2>/dev/null || true

  info "Executed: $method"
  sleep 0.3
}

handle_rpc_json_menu() {
  local ws_key="$1"
  local bg="$2"
  local fg="$3"
  local cur="$4"

  # Category selection loop
  while true; do
    header "RPC JSON - Select Category"

    local categories=(
      "← Back"
      "1. Core System Methods"
      "2. WiFi Methods"
      "3. MQTT Methods"
      "4. Switch/Relay Methods"
      "5. Light/Dimmer Methods"
      "6. Cover/Shutter Methods"
      "7. Input Methods"
      "8. Temperature/Humidity Methods"
      "9. Energy Meter Methods"
      "10. JACK-Specific Methods"
    )

    local category
    category="$(gum choose "${categories[@]}")"

    # Handle cancel or back
    [[ -z "$category" || "$category" == "← Back" ]] && return

    # Handle Core System Methods specially (Shelly/JACK submenu)
    if [[ "$category" == "1. Core System Methods" ]]; then
      while true; do
        header "Core System Methods - Select Device Type"

        local device_type
        device_type="$(gum choose "← Back" "Shelly" "JACK")"

        [[ -z "$device_type" || "$device_type" == "← Back" ]] && break

        local methods_str
        if [[ "$device_type" == "Shelly" ]]; then
          methods_str="$SHELLY_SYSTEM_METHODS"
        else
          methods_str="$JACK_SYSTEM_METHODS"
        fi

        # Method selection for core system
        while true; do
          header "Core System Methods ($device_type) - Select Method"

          # Convert pipe-separated string to array
          IFS='|' read -ra method_array <<< "$methods_str"
          local method
          method="$(gum choose "← Back" "${method_array[@]}")"

          [[ -z "$method" || "$method" == "← Back" ]] && break

          # Prompt for IP address
          header "Enter Device IP Address"
          local ip
          ip="$(gum input --placeholder "e.g., 192.168.34.100" --width 30)"

          [[ -z "$ip" ]] && continue

          execute_rpc_method "$method" "$ip" "$bg" "$fg" "$cur"
        done
      done
    else
      # Regular category - get methods directly
      local methods_str="${RPC_CATEGORIES[$category]}"

      # Method selection loop
      while true; do
        header "$category - Select Method"

        # Convert pipe-separated string to array
        IFS='|' read -ra method_array <<< "$methods_str"
        local method
        method="$(gum choose "← Back" "${method_array[@]}")"

        [[ -z "$method" || "$method" == "← Back" ]] && break

        # Prompt for IP address
        header "Enter Device IP Address"
        local ip
        ip="$(gum input --placeholder "e.g., 192.168.34.100" --width 30)"

        [[ -z "$ip" ]] && continue

        execute_rpc_method "$method" "$ip" "$bg" "$fg" "$cur"
      done
    fi
  done
}

# ---------- workspace handlers ----------

get_workspace_config() {
  local ws_key="$1"
  local field="$2"
  yaml ".workspaces[] | select(.key==\"$ws_key\") | .$field"
}

get_workspace_color() {
  local ws_key="$1"
  local color_key
  color_key="$(echo "$ws_key" | tr '[:upper:]' '[:lower:]')"
  yaml ".colors.${color_key}.$2"
}

handle_simple_workspace() {
  # Workspace with no modules - launch directly
  local ws_key="$1"

  local root_ref root_raw root
  local bg fg cur title

  root_ref="$(get_workspace_config "$ws_key" "root_ref")"
  root_raw="$(yaml ".repo_roots.${root_ref}")"
  root="$(resolve_path "$root_raw")"

  bg="$(get_workspace_color "$ws_key" "background")"
  fg="$(get_workspace_color "$ws_key" "foreground")"
  cur="$(get_workspace_color "$ws_key" "cursor")"
  title="$(get_workspace_config "$ws_key" "title_base")"

  local context
  context="$(print_context "$ws_key" "" "" "" "$root")"

  # Determine claude command based on workspace
  local claude_cmd="claude"
  if [[ "$ws_key" == "SSDD" ]]; then
    claude_cmd="claude --dangerously-skip-permissions"
  fi

  if launch_window "$title" "$root" "$bg" "$fg" "$cur" "$claude_cmd" "$context"; then
    info "Launched: $title"
    sleep 0.5
    exit 0
  fi
}

handle_modular_workspace() {
  # Workspace with modules and modes
  local ws_key="$1"

  local root_ref root_raw root
  root_ref="$(get_workspace_config "$ws_key" "root_ref")"
  root_raw="$(yaml ".repo_roots.${root_ref}")"
  root="$(resolve_path "$root_raw")"

  if ! validate_directory "$root" "$ws_key root"; then
    return
  fi

  # Module selection loop
  while true; do
    header "Select Module ($ws_key)"

    local module
    module="$(gum choose "← Back" "root" "greengrass-components" "mobile-app" "aws-infrastructure" "viso" "jack" "imagebuild" "iOS Monitor" "Serial Monitor" "RPC JSON")"

    # Handle cancel or back
    [[ -z "$module" || "$module" == "← Back" ]] && return

    local bg fg cur
    bg="$(get_workspace_color "$ws_key" "background")"
    fg="$(get_workspace_color "$ws_key" "foreground")"
    cur="$(get_workspace_color "$ws_key" "cursor")"

    # Handle monitor options directly (no mode selection)
    case "$module" in
      "iOS Monitor")
        local title="$ws_key – iOS Monitor"
        local ios_cwd="$root/mobile-app"

        if ! validate_directory "$ios_cwd" "mobile-app"; then
          continue
        fi

        kitty @ launch \
          --type=os-window \
          --cwd "$ios_cwd" \
          --title "$title" \
          bash -lc "flutter run"

        sleep 0.1
        kitty @ set-colors --match "title:$title" \
          background="$bg" foreground="$fg" cursor="$cur" 2>/dev/null || true

        info "Launched: $title"
        sleep 0.5
        exit 0
        ;;

      "Serial Monitor")
        local title="$ws_key – Serial Monitor"
        local serial_cwd="$root/jack/jack-core"

        if ! validate_directory "$serial_cwd" "jack/jack-core"; then
          continue
        fi

        kitty @ launch \
          --type=os-window \
          --cwd "$serial_cwd" \
          --title "$title" \
          bash -lc "pio device monitor"

        sleep 0.1
        kitty @ set-colors --match "title:$title" \
          background="$bg" foreground="$fg" cursor="$cur" 2>/dev/null || true

        info "Launched: $title"
        sleep 0.5
        exit 0
        ;;

      "RPC JSON")
        handle_rpc_json_menu "$ws_key" "$bg" "$fg" "$cur"
        ;;
    esac

    # Regular module - proceed to mode selection
    local mod_path cwd
    mod_path="$(yaml ".workspaces[] | select(.key==\"$ws_key\") | .modules[] | select(.key==\"$module\") | .path")"
    cwd="$root/$mod_path"

    if ! validate_directory "$cwd" "Module"; then
      continue
    fi

    # Mode selection loop
    while true; do
      header "Select Mode ($ws_key → $module)"

      local mode
      mode="$(gum choose "← Back" "PLAN / DESIGN" "IMPLEMENT")"

      # Handle cancel or back
      [[ -z "$mode" || "$mode" == "← Back" ]] && break

      local mode_id
      mode_id="$(yaml ".workspaces[] | select(.key==\"$ws_key\") | .modes[] | select(.key==\"$mode\") | .mode_id")"

      local bg fg cur
      bg="$(get_workspace_color "$ws_key" "background")"
      fg="$(get_workspace_color "$ws_key" "foreground")"
      cur="$(get_workspace_color "$ws_key" "cursor")"

      # Handle based on mode_id
      case "$mode_id" in
        PLAN_DESIGN)
          # Launch claude with prd-design agent loaded
          local title="$ws_key – Design – $module"

          kitty @ launch \
            --type=tab \
            --cwd "$cwd" \
            --title "$title" \
            bash -lc "claude --dangerously-skip-permissions 'Read .claude/agents/prd-design.md and confirm you are ready to help with PRD design for this module.'"

          sleep 0.1
          kitty @ set-colors --match "title:$title" \
            background="$bg" foreground="$fg" cursor="$cur" 2>/dev/null || true

          info "Launched: $title"
          sleep 0.5
          exit 0
          ;;

        IMPLEMENT)
          # PRD input loop with back support
          while true; do
            header "Enter PRD ID ($ws_key → $module → Implement)"

            # Show recent PRDs if available
            local recent
            recent="$(get_recent_prds "$module")"
            if [[ -n "$recent" ]]; then
              gum style --faint "Recent: $(echo "$recent" | tr '\n' ' ')"
            fi

            local prd
            prd="$(gum input --placeholder "PRD ID (e.g. GG-SENSOR-2025-001)" --width 50)"

            # Handle cancel or empty (go back)
            [[ -z "$prd" ]] && break

            # Save to recent
            save_recent_prd "$prd" "$module"

            local title="$ws_key – Implement – $module – $prd"

            # Launch directly - keep shell open after script completes
            kitty @ launch \
              --type=tab \
              --cwd "$cwd" \
              --title "$title" \
              bash -lc "echo 'Starting PRD: $prd'; echo 'Directory: $cwd'; echo '---'; $root/implement_prd.sh \"$prd\"; echo ''; echo 'Press enter to close...'; read"

            sleep 0.1
            kitty @ set-colors --match "title:$title" \
              background="$bg" foreground="$fg" cursor="$cur" 2>/dev/null || true

            info "Launched: $title"
            sleep 0.5
            exit 0
          done
          ;;

        *)
          # Generic mode - just launch with mode in title
          local title="$ws_key – $mode – $module"
          local context
          context="$(print_context "$ws_key" "$module" "$mode" "" "$cwd")"

          if launch_window "$title" "$cwd" "$bg" "$fg" "$cur" "claude" "$context"; then
            info "Launched: $title"
            sleep 0.5
            exit 0
          fi
          ;;
      esac
    done
  done
}

# ---------- main ----------

main() {
  # Trap for clean exit
  trap 'echo ""; exit 0' INT TERM

  while true; do
    header "Select Workspace"

    local workspace
    workspace="$(gum choose "Exit" "GALT" "SSDD")"

    # Handle cancel or exit
    [[ -z "$workspace" || "$workspace" == "Exit" ]] && exit 0

    # Check if workspace has modules
    local has_modules
    has_modules="$(yaml ".workspaces[] | select(.key==\"$workspace\") | .modules | length")"

    if [[ "$has_modules" == "0" || "$has_modules" == "null" || -z "$has_modules" ]]; then
      handle_simple_workspace "$workspace"
    else
      handle_modular_workspace "$workspace"
    fi
  done
}

main "$@"
