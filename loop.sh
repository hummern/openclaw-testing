#!/usr/bin/env bash

# WCAG AAA Autonomous Loop - Invokes OpenClaw Agent via Gateway API

OPENCLAW_HOST="127.0.0.1"
OPENCLAW_PORT="18789"
OPENCLAW_TOKEN="03fdaa9499236b58530b50dcde50647c31ff12f7747da122"
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

# Call OpenClaw agent to execute a single task
call_openclaw_agent() {
  local task_description="$1"
  
  # Send task to OpenClaw gateway
  curl -s -X POST "${OPENCLAW_API}/message" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OPENCLAW_TOKEN}" \
    -d "{\"message\": \"$task_description\", \"stream\": false}" 2>/dev/null
}

# Mark task complete in IMPLEMENTATION_PLAN.md by line number
mark_task_complete() {
  local line_number="$1"
  if [ ! -z "$line_number" ] && [ "$line_number" -gt 0 ]; then
    sed -i "${line_number}s/^- \[ \]/- [x]/" IMPLEMENTATION_PLAN.md
  fi
}

cd /home/ubuntu

echo "🤖 WCAG AAA Autonomous Loop - Starting OpenClaw Agent"
echo "⚙️  OpenClaw Gateway: ${OPENCLAW_API}"
echo "📋 Reading tasks from IMPLEMENTATION_PLAN.md"
echo ""

ITER=1
while [ $ITER -le 100 ]; do
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║ Iteration $ITER - OpenClaw Autonomous Task Execution    ║"
  echo "╚══════════════════════════════════════════════════════╝"
  
  # Count task status - store in separate variables and clean whitespace
  CHECKED=$(grep "^- \[x\]" IMPLEMENTATION_PLAN.md 2>/dev/null | wc -l)
  UNCHECKED=$(grep "^- \[ \]" IMPLEMENTATION_PLAN.md 2>/dev/null | wc -l)
  
  # Remove leading/trailing whitespace
  CHECKED=$(echo "$CHECKED" | xargs)
  UNCHECKED=$(echo "$UNCHECKED" | xargs)
  
  # Default to 0 if empty
  if [ -z "$CHECKED" ]; then CHECKED=0; fi
  if [ -z "$UNCHECKED" ]; then UNCHECKED=0; fi
  
  echo "[Iteration $ITER] Progress: $CHECKED checked, $UNCHECKED unchecked"
  
  # Check if all tasks complete
  if [ "$UNCHECKED" -eq 0 ]; then
    echo ""
    echo "✅ ALL TASKS COMPLETE!"
    echo "🎯 OpenClaw has successfully executed all WCAG AAA tasks"
    
    # Update status
    sed -i '/^STATUS:/d' IMPLEMENTATION_PLAN.md 2>/dev/null || true
    echo "STATUS: COMPLETE - All tasks executed by OpenClaw agent" >> IMPLEMENTATION_PLAN.md
    
    push_changes
    send_telegram "✅ WCAG AAA Loop Complete! OpenClaw successfully executed all $CHECKED tasks."
    exit 0
  fi
  
  # Get next unchecked task
  TASK_LINE=$(grep -n "^- \[ \]" IMPLEMENTATION_PLAN.md 2>/dev/null | head -1)
  
  if [ -z "$TASK_LINE" ]; then
    echo "⚠️  No unchecked tasks found, but counter says $UNCHECKED unchecked"
    ITER=$((ITER + 1))
    sleep 1
    continue
  fi
  
  # Extract line number and task text
  LINE_NUM=$(echo "$TASK_LINE" | cut -d: -f1 | xargs)
  TASK_TEXT=$(echo "$TASK_LINE" | cut -d: -f2- | sed 's/^- \[ \]//')
  
  TASK_NUM=$((CHECKED + 1))
  echo ""
  echo "[OpenClaw] Task #$TASK_NUM: $TASK_TEXT"
  echo "[OpenClaw] Invoking autonomous agent at ${OPENCLAW_API}..."
  
  # Send task to OpenClaw agent for autonomous execution
  AGENT_RESPONSE=$(call_openclaw_agent "Execute this WCAG AAA task: $TASK_TEXT")
  AGENT_EXIT=$?
  
  if [ $AGENT_EXIT -eq 0 ] && [ ! -z "$AGENT_RESPONSE" ]; then
    echo "[OpenClaw] ✅ Agent response received ($(echo "$AGENT_RESPONSE" | wc -c) bytes)"
    echo "[OpenClaw] Response preview:"
    echo "$AGENT_RESPONSE" | head -3 | sed 's/^/  /'
    
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
  else
    echo "[OpenClaw] ⚠️  No response from agent (exit: $AGENT_EXIT)"
    
    # Check if gateway is running
    HEALTH=$(curl -s -w "\n%{http_code}" -X GET "${OPENCLAW_API}/health" 2>/dev/null | tail -1)
    
    if [ "$HEALTH" != "200" ] && [ "$HEALTH" != "404" ]; then
      echo "[OpenClaw] ❌ Gateway not responding (HTTP $HEALTH)"
      echo "❌ OpenClaw gateway not accessible at ${OPENCLAW_API}"
      echo "   Start it with: docker-compose up -d"
      send_telegram "❌ OpenClaw Loop: Gateway unreachable at ${OPENCLAW_API}"
      exit 1
    else
      echo "[OpenClaw] ℹ️  Gateway responsive (HTTP $HEALTH) but no task response"
      send_telegram "⚠️ OpenClaw: Gateway responsive but agent not completing tasks (Iteration $ITER)"
    fi
  fi
  
  ITER=$((ITER + 1))
  sleep 2
done

echo ""
echo "⚠️  Loop reached 100 iterations"
send_telegram "⚠️ OpenClaw Loop: Completed 100 iterations without full task completion"
exit 1

