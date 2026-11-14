"""Run the TA API journeys on a disposable database without browser automation."""
import json
from pathlib import Path

from support import Sandbox
import ta_check


if __name__ == '__main__':
    with Sandbox('ta') as sandbox:
        ta_check.run_api(sandbox)
    results = [dict(zip(('check', 'layer', 'status', 'evidence'), row))
               for row in ta_check.RESULTS]
    target = Path(__file__).resolve().parents[2] / 'review' / 'ta-logic-api-results.json'
    target.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    failures = [row for row in results if row['status'] == 'FAIL']
    print(f"TA API audit: {len(results) - len(failures)}/{len(results)} passed")
    raise SystemExit(bool(failures))
