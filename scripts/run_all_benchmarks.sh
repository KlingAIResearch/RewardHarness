#!/usr/bin/env bash
# Run benchmarks on ALL checkpoints (iter_0 through iter_9) sequentially.
# Each benchmark takes ~7 min, total ~70 min.
# Results saved to results/benchmark_iter_N.json
set -uo pipefail

PYTHON="${VLLM_PYTHON:-python}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$PROJECT_ROOT/configs/default.yaml"
CHECKPOINTS_DIR="$PROJECT_ROOT/results/checkpoints"
RESULTS_DIR="$PROJECT_ROOT/results"

echo "=== Running ALL benchmarks ==="
echo "Start: $(date)"

for iter_dir in "$CHECKPOINTS_DIR"/iter_*; do
    iter_num=$(basename "$iter_dir" | sed 's/iter_//')
    outfile="$RESULTS_DIR/benchmark_iter_${iter_num}.json"

    echo ""
    echo "============================================================"
    echo "Benchmark: iter_${iter_num} ($(date))"
    echo "Library dir: $iter_dir"
    echo "Output: $outfile"
    echo "============================================================"

    # Point benchmark at this checkpoint's library
    $PYTHON "$PROJECT_ROOT/scripts/run_benchmark.py" \
        --config "$CONFIG" \
        --library-dir "$iter_dir" \
        2>&1

    # Move the result file
    if [ -f "$RESULTS_DIR/benchmark_results.json" ]; then
        cp "$RESULTS_DIR/benchmark_results.json" "$outfile"
        echo "Saved: $outfile"
    fi
done

echo ""
echo "=== ALL BENCHMARKS COMPLETE ==="
echo "End: $(date)"
echo ""

# Summary table — include all five scores so it's obvious which checkpoint won on `average`.
echo "Iter | K=2    | K=3    | K=4    | GenAI  | Avg"
echo "-----|--------|--------|--------|--------|--------"
for iter_dir in "$CHECKPOINTS_DIR"/iter_*; do
    iter_num=$(basename "$iter_dir" | sed 's/iter_//')
    outfile="$RESULTS_DIR/benchmark_iter_${iter_num}.json"
    if [ -f "$outfile" ]; then
        $PYTHON -c "
import json, sys
d = json.load(open(sys.argv[1]))
get = lambda k: d.get(k, {}).get('accuracy', 0) if isinstance(d.get(k), dict) else 0
k2 = get('k2'); k3 = get('k3'); k4 = get('k4'); gen = get('genai_bench')
avg = d.get('average', 0)
print(f'  {sys.argv[2]}  | {k2:.4f} | {k3:.4f} | {k4:.4f} | {gen:.4f} | {avg:.4f}')
" "$outfile" "$iter_num"
    fi
done
