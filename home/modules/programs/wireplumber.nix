{ lib, config, pkgs, ... }:

let
  # Centralized audio configuration
  audioConfig = {
    primarySink = "alsa_output.usb-R__DE_R__DE_AI-Micro_5C4F2EEB-01.analog-stereo";
    secondarySink = "alsa_output.pci-0000_03_00.1.hdmi-stereo-extra1";
    obsVirtualSink = "obs_sink";
    discordVirtualSink = "discord_sink"; 
    latencyMs = 1;
  };

  # Common functions used across scripts
  commonFunctions = ''
    # Error handling function
    check_command() {
        if [ $? -ne 0 ]; then
            echo "Error: $1 failed"
            exit 1
        fi
    }

    # Function to safely unload modules
    cleanup_modules() {
        echo "Cleaning up existing virtual audio modules..."
        pactl unload-module module-null-sink 2>/dev/null || true
        pactl unload-module module-loopback 2>/dev/null || true
        pactl unload-module module-combine-sink 2>/dev/null || true
    }

    # Function to check if sink exists
    sink_exists() {
        pactl list short sinks | grep -q "^[0-9]*[[:space:]]*$1[[:space:]]"
    }

    # Function to validate primary sink
    validate_primary_sink() {
        if ! sink_exists "${audioConfig.primarySink}"; then
            echo "Warning: Primary sink '${audioConfig.primarySink}' not found!"
            echo "Available sinks:"
            pactl list short sinks
            echo ""
            echo "Please update the primarySink in your configuration."
            return 1
        fi
        return 0
    }
  '';
in
{
  home.packages = [
    # Main streaming setup script
    (pkgs.writeShellScriptBin "setup-streaming-audio" ''
      #!/usr/bin/env bash
      set -euo pipefail  # Exit on error, undefined vars, pipe failures

      # Audio configuration
      PRIMARY_SINK="${audioConfig.primarySink}"
      OBS_SINK="${audioConfig.obsVirtualSink}"
      DISCORD_SINK="${audioConfig.discordVirtualSink}"
      LATENCY_MS="${toString audioConfig.latencyMs}"

      ${commonFunctions}

      echo "Setting up streaming-friendly audio routing..."

      # Validate primary sink exists
      if ! validate_primary_sink; then
          exit 1
      fi

      # Clean up any existing setup
      cleanup_modules

      # Create virtual sinks
      echo "Creating virtual sinks..."
      
      echo "  → Creating OBS sink: '$OBS_SINK'"
      OBS_MODULE_ID=$(pactl load-module module-null-sink \
          sink_name="$OBS_SINK" \
          sink_properties=device.description="OBS-Stream-Audio")
      check_command "OBS sink creation"

      echo "  → Creating Discord sink: '$DISCORD_SINK'"
      DISCORD_MODULE_ID=$(pactl load-module module-null-sink \
          sink_name="$DISCORD_SINK" \
          sink_properties=device.description="Discord-Only")  
      check_command "Discord sink creation"

      # Create loopbacks to headphones
      echo "Creating loopbacks to headphones..."
      
      echo "  → OBS sink → headphones"
      LOOPBACK1_ID=$(pactl load-module module-loopback \
          source="$OBS_SINK.monitor" \
          sink="$PRIMARY_SINK" \
          latency_msec="$LATENCY_MS")
      check_command "OBS loopback creation"

      echo "  → Discord sink → headphones"  
      LOOPBACK2_ID=$(pactl load-module module-loopback \
          source="$DISCORD_SINK.monitor" \
          sink="$PRIMARY_SINK" \
          latency_msec="$LATENCY_MS")
      check_command "Discord loopback creation"

      # Set OBS sink as default
      echo "Setting OBS sink as default..."
      pactl set-default-sink "$OBS_SINK"
      check_command "Setting default sink"

      echo ""
      echo "✅ STREAMING SETUP COMPLETE!"
      echo "=============================="
      echo "🎧 obs_sink      - All apps except Discord (OBS captures this)"
      echo "🎮 discord_sink  - Discord only (excluded from OBS)"  
      echo "🔊 Both route to your headphones via loopback"
      echo ""
      echo "📋 NEXT STEPS:"
      echo "1. Discord: Settings → Voice & Video → Output → 'Discord-Only'"
      echo "2. OBS: Audio Output Capture → Select 'obs_sink'"
      echo "3. All other apps use 'obs_sink' by default"
      echo ""
      echo "Available sinks:"
      pactl list short sinks
    '')

    # Audio debugging tool
    (pkgs.writeShellScriptBin "list-audio-apps" ''
      #!/usr/bin/env bash

      ${commonFunctions}

      echo "Current audio applications and routing:"
      echo "======================================="

      if ! pactl list short sink-inputs | grep -q .; then
          echo "No active audio applications found."
          echo ""
      else
          pactl list short sink-inputs | while IFS= read -r line; do
              INPUT_ID=$(echo "$line" | cut -f1)
              SINK_ID=$(echo "$line" | cut -f2)
              
              # Get sink name safely
              SINK_NAME=$(pactl list short sinks | grep "^$SINK_ID" | cut -f2 || echo "unknown")
              
              # Get application name safely
              APP_NAME=$(pactl list sink-inputs | grep -A 30 "Sink Input #$INPUT_ID" | \
                        grep "application.name" | cut -d'"' -f2 || echo "unknown")
              
              echo "🎵 '$APP_NAME' → $SINK_NAME"
          done
          echo ""
      fi

      echo "Available sinks:"
      echo "==============="
      pactl list short sinks | while IFS= read -r line; do
          SINK_ID=$(echo "$line" | cut -f1)
          SINK_NAME=$(echo "$line" | cut -f2)  
          SINK_STATUS=$(echo "$line" | awk '{print $NF}')
          
          # Add status indicator
          case "$SINK_STATUS" in
              *"RUNNING"*) echo "🟢 $SINK_NAME (active)" ;;
              *"IDLE"*) echo "🟡 $SINK_NAME (idle)" ;;
              *"SUSPENDED"*) echo "🔴 $SINK_NAME (suspended)" ;;
              *) echo "⚪ $SINK_NAME" ;;
          esac
      done
    '')

    # Audio reset tool
    (pkgs.writeShellScriptBin "reset-audio" ''
      #!/usr/bin/env bash
      set -euo pipefail

      PRIMARY_SINK="${audioConfig.primarySink}"

      ${commonFunctions}

      echo "Resetting audio to normal configuration..."

      # Validate primary sink exists before resetting to it
      if ! validate_primary_sink; then
          echo "Cannot reset to primary sink - it doesn't exist!"
          echo "Please fix your audio configuration first."
          exit 1
      fi

      # Clean up virtual modules
      cleanup_modules

      # Reset default sink
      echo "Restoring default sink to: $PRIMARY_SINK"
      pactl set-default-sink "$PRIMARY_SINK"
      check_command "Resetting default sink"

      echo ""
      echo "✅ Audio reset complete!"
      echo "📡 Default sink: $PRIMARY_SINK"
      echo ""
      echo "Current sinks:"
      pactl list short sinks
    '')
  ];
}
