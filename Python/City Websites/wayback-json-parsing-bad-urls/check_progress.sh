#!/bin/bash
# Check progress of the investigation

echo "========================================"
echo "Investigation Progress Monitor"
echo "========================================"
echo ""

# Check if process is running
if pgrep -f "investigate_bad_urls.py" > /dev/null; then
    echo "✅ Investigation is RUNNING"
    echo ""
else
    echo "⚠️  Investigation is NOT running"
    echo ""
fi

# Show last few lines of output
if [ -f "investigation_output.log" ]; then
    echo "📊 Last 15 lines of output:"
    echo "----------------------------------------"
    tail -n 15 investigation_output.log
    echo "----------------------------------------"
    echo ""
fi

# Check reports directory
if [ -d "reports" ]; then
    echo "📁 Reports directory:"
    ls -lh reports/ 2>/dev/null || echo "   (empty)"
    echo ""
fi

# Show summary if available
if [ -f "reports/investigation_summary.json" ]; then
    echo "📈 Current Summary:"
    echo "----------------------------------------"
    python3 -c "import json; s=json.load(open('reports/investigation_summary.json')); print(f\"  Total: {s['total_investigated']}\"); print(f\"  Recoverable: {s['recoverable']} ({s['recovery_rate']:.1f}%)\"); print(f\"  Marginal: {s['marginal']}\"); print(f\"  Unrecoverable: {s['unrecoverable']}\"); print(f\"  Duration: {s['duration_seconds']:.0f}s\")" 2>/dev/null
    echo "----------------------------------------"
    echo ""
fi

echo "Commands:"
echo "  tail -f investigation_output.log  # Watch live output"
echo "  pkill -f investigate_bad_urls.py  # Stop investigation"
echo ""
