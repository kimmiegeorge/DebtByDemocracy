#!/bin/bash
# Quick start script for investigating bad URLs - Texas

echo "=========================================="
echo "Bad URLs Recovery Pipeline - Texas"
echo "=========================================="
echo ""

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Check if dependencies are installed
if ! python3 -c "import pandas" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Run investigation on first 5 URLs as a test
echo ""
echo "Running investigation on first 5 bad URLs as a test..."
echo ""
python3 investigate_bad_urls.py --limit 5 --sample-size 5

echo ""
echo "=========================================="
echo "Investigation complete!"
echo "Check the reports/ directory for results"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review reports/investigation_results.json"
echo "2. Check reports/recoverable_urls.csv for URLs that can be recovered"
echo "3. To investigate all bad URLs, run:"
echo "   python3 investigate_bad_urls.py"
echo ""

