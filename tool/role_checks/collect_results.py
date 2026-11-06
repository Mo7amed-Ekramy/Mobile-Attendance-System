"""Summarize retained role scenarios; no database access or browser startup."""
from collections import Counter, defaultdict
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    reports = ROOT / 'review'
    roles = {}
    for role, name in [('doctor', 'doctor-api-results.json'), ('student', 'student-role-results.json')]:
        rows = json.loads((reports / name).read_text(encoding='utf-8'))
        normalized = []
        for row in rows:
            if isinstance(row, list):
                feature, scenario, status, detail = row
                normalized.append({'scenario': feature + ': ' + scenario,
                    'layer': 'Chrome UI' if feature.startswith('UI ') else 'API',
                    'status': status, 'detail': detail})
            else:
                normalized.append({'scenario': row['name'], 'layer': row['layer'],
                    'status': row['status'], 'detail': row['detail']})
        roles[role] = normalized
    ta_rows = []
    for line in (reports / 'ta-role-feedback.md').read_text(encoding='utf-8').splitlines():
        if not line.startswith('| '):
            continue
        cells = [cell.strip() for cell in line.strip('|').split('|')]
        if len(cells) >= 4 and cells[2] in ('PASS', 'FAIL', 'NOT TESTABLE', 'NOT TESTED', 'BLOCKED', 'INCOMPLETE', 'N/A'):
            ta_rows.append({'scenario': cells[0], 'layer': cells[1], 'status': cells[2],
                'detail': '|'.join(cells[3:])})
    roles['ta'] = ta_rows
    summary = {}
    for role, rows in roles.items():
        layers = defaultdict(Counter)
        for row in rows:
            layers[row['layer']][row['status']] += 1
        summary[role] = {'scenarios': len(rows), 'statuses': dict(Counter(row['status'] for row in rows)),
            'layers': {name: dict(counts) for name, counts in layers.items()},
            'failures': [row for row in rows if row['status'] == 'FAIL'],
            'unverified': [row for row in rows if row['status'] not in ('PASS', 'FAIL')]}
    result = {'roles': summary, 'total_scenarios': sum(len(rows) for rows in roles.values()),
        'statuses': dict(Counter(row['status'] for rows in roles.values() for row in rows))}
    result['focused_login_reruns'] = {}
    for name in ('student-login-ui-results.json', 'student-login-narrow-results.json'):
        source = reports / name
        if source.exists():
            rows = json.loads(source.read_text(encoding='utf-8'))
            result['focused_login_reruns'][name] = {
                'scenarios': len(rows), 'statuses': dict(Counter(row['status'] for row in rows))}
    (reports / 'role-test-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({role: {'scenarios': data['scenarios'], 'statuses': data['statuses'], 'layers': data['layers']}
        for role, data in summary.items()}, indent=2))


if __name__ == '__main__':
    main()
