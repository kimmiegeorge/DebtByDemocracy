#!/bin/bash
# Check progress of Texas bad URLs investigation

echo "=========================================="
echo "Texas Bad URLs Investigation - Progress"
echo "=========================================="
echo ""

# Check if reports directory exists
if [ ! -d "reports" ]; then
    echo "❌ No reports directory found yet"
    echo "Run ./run_investigation.sh to start"
    exit 1
fi

# Check for summary file
if [ -f "reports/investigation_summary.json" ]; then
    echo "📊 Investigation Summary:"
    echo "------------------------"
    cat reports/investigation_summary.json | python3 -m json.tool 2>/dev/null || cat reports/investigation_summary.json
    echo ""
fi

# Check for recoverable URLs
if [ -f "reports/recoverable_urls.csv" ]; then
    recoverable_count=$(tail -n +2 reports/recoverable_urls.csv | wc -l)
    echo "✅ Recoverable URLs found: $recoverable_count"
    echo ""
    echo "Preview of recoverable URLs:"
    echo "----------------------------"
    head -10 reports/recoverable_urls.csv
    echo ""
fi

# Check reports directory contents
echo "📁 Reports Directory:"
echo "--------------------"
ls -lh reports/
echo ""

echo "=========================================="
echo "To view full results:"
echo "  cat reports/investigation_results.json"
echo "  cat reports/recoverable_urls.csv"
echo "=========================================="

