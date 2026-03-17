#!/usr/bin/env bash

# WCAG AAA Autonomous Loop - OpenClaw Integration
# Proper endpoint: POST /v1/chat/completions

OPENCLAW_HOST="127.0.0.1"
OPENCLAW_PORT="18789"
OPENCLAW_TOKEN="85f716d57d8d66935b81f07fa88978dcb0b4b03912fdd69ff75070451b7f08f1"
OPENCLAW_API="http://${OPENCLAW_HOST}:${OPENCLAW_PORT}"

TELEGRAM_BOT="8523759950:AAFugiYjVqdMbleLfUgF6pOpzBYUxZaINQM"
TELEGRAM_CHAT_ID="8331741012"
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT}/sendMessage"

send_telegram() {
  local msg="$1"
  curl -s -X POST "$TELEGRAM_API" \
    -H 'Content-Type: application/json' \
    -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"$msg\", \"parse_mode\": \"HTML\"}" > /dev/null 2>&1 || true
}

push_changes() {
  cd /home/ubuntu
  git add -A 2>/dev/null || true
  git commit -m "WCAG Loop: Autonomous task completion $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
  git push -f origin master:main 2>/dev/null || true
}

# Call OpenClaw agent via proper /v1/chat/completions endpoint
call_openclaw_agent() {
  local task_description="$1"
  
  # Build deterministic task prompt
  local task_prompt=$(cat <<EOF
You are in a strict Wiggum loop for WCAG AAA HTML5 task execution.

TASK: $task_description

RULES:
- Execute ONLY this exact task
- Modify files directly in /home/ubuntu
- Use git to commit your changes
- Do NOT explain or ask questions
- Do NOT stop early
- Return a SHORT one-line status (success or error)
- If you modify files, end with: DONE

EOF
)
  
  # Send to OpenClaw via /v1/chat/completions endpoint
  curl -sS -X POST "${OPENCLAW_API}/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENCLAW_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "x-openclaw-agent-id: main" \
    -d "{
      \"model\": \"openclaw\",
      \"messages\": [
        {
          \"role\": \"user\",
          \"content\": \"${task_prompt}\"
        }
      ],
      \"stream\": false
    }" 2>/dev/null
}

# Extract content from OpenClaw response JSON
extract_agent_content() {
  local response="$1"
  echo "$response" | jq -r '.choices[0].message.content // ""' 2>/dev/null
}

# Mark task complete in IMPLEMENTATION_PLAN.md
mark_task_complete() {
  local line_number="$1"
  if [ ! -z "$line_number" ] && [ "$line_number" -gt 0 ]; then
    sed -i "${line_number}s/^- \[ \]/- [x]/" IMPLEMENTATION_PLAN.md
  fi
}

cd /home/ubuntu

echo "🤖 WCAG AAA Autonomous Loop - OpenClaw Agent"
echo "⚙️  OpenClaw Gateway: ${OPENCLAW_API}/v1/chat/completions"
echo "📋 Reading tasks from IMPLEMENTATION_PLAN.md"
echo ""

ITER=1
while [ $ITER -le 100 ]; do
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║ Iteration $ITER - OpenClaw Autonomous Task Execution    ║"
  echo "╚══════════════════════════════════════════════════════╝"
  
  # Count task status
  CHECKED=$(grep "^- \[x\]" IMPLEMENTATION_PLAN.md 2>/dev/null | wc -l | xargs)
  UNCHECKED=$(grep "^- \[ \]" IMPLEMENTATION_PLAN.md 2>/dev/null | wc -l | xargs)
  
  if [ -z "$CHECKED" ]; then CHECKED=0; fi
  if [ -z "$UNCHECKED" ]; then UNCHECKED=0; fi
  
  echo "[Iteration $ITER] Progress: $CHECKED checked, $UNCHECKED unchecked"
  
  # Check if complete
  if [ "$UNCHECKED" -eq 0 ]; then
    echo ""
    echo "✅ ALL TASKS COMPLETE!"
    echo "🎯 OpenClaw has successfully executed all WCAG AAA tasks"
    
    sed -i '/^STATUS:/d' IMPLEMENTATION_PLAN.md 2>/dev/null || true
    echo "STATUS: COMPLETE - All tasks executed by OpenClaw agent" >> IMPLEMENTATION_PLAN.md
    
    push_changes
    send_telegram "✅ WCAG AAA Loop Complete! OpenClaw successfully executed all $CHECKED tasks."
    exit 0
  fi
  
  # Get next unchecked task
  TASK_LINE=$(grep -n "^- \[ \]" IMPLEMENTATION_PLAN.md 2>/dev/null | head -1)
  
  if [ -z "$TASK_LINE" ]; then
    echo "⚠️  No unchecked tasks found"
    ITER=$((ITER + 1))
    sleep 1
    continue
  fi
  
  LINE_NUM=$(echo "$TASK_LINE" | cut -d: -f1 | xargs)
  TASK_TEXT=$(echo "$TASK_LINE" | cut -d: -f2- | sed 's/^- \[ \]//')
  
  TASK_NUM=$((CHECKED + 1))
  echo ""
  echo "[OpenClaw] Task #$TASK_NUM: $TASK_TEXT"
  echo "[OpenClaw] Invoking agent..."
  
  # Call agent
  AGENT_RESPONSE=$(call_openclaw_agent "$TASK_TEXT")
  AGENT_EXIT=$?
  
  if [ $AGENT_EXIT -eq 0 ] && [ ! -z "$AGENT_RESPONSE" ]; then
    # Parse JSON response
    AGENT_CONTENT=$(extract_agent_content "$AGENT_RESPONSE")
    
    if [ ! -z "$AGENT_CONTENT" ]; then
      echo "[OpenClaw] ✅ Agent response received"
      echo "[Response] $AGENT_CONTENT" | head -1 | sed 's/^/  /'
      
      # Check for error indicators
      if echo "$AGENT_CONTENT" | grep -qi "error\|failed\|unable"; then
        echo "⚠️  Agent reported error, will retry next iteration"
      else
        # Mark task complete
        mark_task_complete "$LINE_NUM"
        echo "✅ Task #$TASK_NUM marked complete"
        
        # Telegram update every 3 iterations
        if [ $((ITER % 3)) -eq 0 ]; then
          send_telegram "🤖 OpenClaw Progress: $TASK_NUM/$((TASK_NUM + UNCHECKED - 1)) tasks (Iteration $ITER)"
        fi
        
        # Push changes every 5 iterations
        if [ $((ITER % 5)) -eq 0 ]; then
          push_changes
          send_telegram "📤 OpenClaw: Pushed changes to main (Iteration $ITER)"
        fi
      fi
    else
      echo "[OpenClaw] ⚠️  Empty response (check /v1/chat/completions endpoint enabled)"
    fi
  else
    echo "[OpenClaw] ⚠️  No response from agent (curl exit: $AGENT_EXIT)"
    
    # Check gateway health
    HEALTH_RESPONSE=$(curl -sS -w "\n%{http_code}" -X GET "${OPENCLAW_API}/health" 2>/dev/null)
    HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -1)
    
    if [ -z "$HEALTH_CODE" ] || [ "$HEALTH_CODE" = "000" ]; then
      echo "❌ OpenClaw gateway not accessible at ${OPENCLAW_API}"
      send_telegram "❌ OpenClaw Loop: Gateway unreachable at ${OPENCLAW_API}"
      exit 1
    else
      echo "ℹ️  Gateway responsive (HTTP $HEALTH_CODE)"
      echo "⚠️  Endpoint /v1/chat/completions might not be enabled"
      send_telegram "⚠️ OpenClaw: Gateway responsive but endpoint issue (HTTP $HEALTH_CODE)"
    fi
  fi
  
  ITER=$((ITER + 1))
  sleep 2
done

echo ""
echo "⚠️  Loop reached 100 iterations"
send_telegram "⚠️ OpenClaw Loop: Completed 100 iterations"
exit 1

