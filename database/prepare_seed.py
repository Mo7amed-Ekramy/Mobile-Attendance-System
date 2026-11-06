"""Convert original .NET JSON seeds to PostgreSQL SQL using only Python stdlib."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_SOURCE = HERE.parent.parent / "legacy-attendance-system"
FILES = ("Department", "DepartmentSection", "User", "Course", "CourseDepartment", "CourseSection", "Student")


def read_sources(source: Path) -> tuple[dict, str, dict]:
    data, provenance = {}, {}
    digest = hashlib.sha256()
    for name in FILES:
        path = source / "Seeding" / f"{name}.json"
        raw = path.read_bytes()
        parsed = json.loads(raw.decode("utf-8-sig"))
        if not isinstance(parsed, list) or not parsed:
            raise ValueError(f"{path.name}: expected a nonempty JSON list")
        rows = []
        for item in parsed:
            if not isinstance(item, dict):
                raise ValueError(f"{path.name}: expected JSON objects")
            normalized = {key.lower(): value for key, value in item.items()}
            if len(normalized) != len(item):
                raise ValueError(f"{path.name}: duplicate keys with different casing")
            rows.append(normalized)
        data[name] = rows
        relative = f"Seeding/{name}.json"
        provenance[relative] = {"sha256": hashlib.sha256(raw).hexdigest(), "rows": len(rows)}
        digest.update(relative.encode() + b"\0" + raw)
    seeder = source / "Models" / "Data" / "DbSeeder.cs"
    raw = seeder.read_bytes()
    provenance["Models/Data/DbSeeder.cs"] = {"sha256": hashlib.sha256(raw).hexdigest()}
    digest.update(b"Models/Data/DbSeeder.cs\0" + raw)
    return data, digest.hexdigest(), provenance


def indexed(rows: list[dict], name: str) -> dict[int, dict]:
    result = {}
    for row in rows:
        identifier = row.get("id")
        if isinstance(identifier, bool) or not isinstance(identifier, int) or identifier < 0:
            raise ValueError(f"{name}: invalid ID {identifier!r}")
        if identifier in result:
            raise ValueError(f"{name}: duplicate ID {identifier}")
        result[identifier] = row
    return result


def validate(data: dict) -> dict[str, dict]:
    indexes = {name: indexed(data[name], name) for name in FILES}
    usernames = set()
    university_ids = set()
    for name in ("User", "Student"):
        for row in data[name]:
            for field in ("username", "fullname"):
                if not isinstance(row.get(field), str) or not row[field].strip():
                    raise ValueError(f"{name} {row['id']}: missing {field}")
            username = row["username"].lower()
            if username in usernames:
                raise ValueError(f"Duplicate username: {username}")
            usernames.add(username)
    for row in data["User"]:
        if row["role"].lower() not in {"admin", "doctor", "ta"}:
            raise ValueError(f"Staff {row['id']}: unexpected role")
    for row in data["DepartmentSection"]:
        if row["departmentid"] not in indexes["Department"] or row["number"] <= 0:
            raise ValueError(f"Department section {row['id']}: invalid department/number")
    for row in data["Course"]:
        doctor = indexes["User"].get(row["doctorid"])
        if not doctor or doctor["role"].lower() != "doctor":
            raise ValueError(f"Course {row['id']}: instructor is not a doctor")
    department_pairs = set()
    for row in data["CourseDepartment"]:
        pair = (row["courseid"], row["departmentid"])
        if pair[0] not in indexes["Course"] or pair[1] not in indexes["Department"] or pair in department_pairs:
            raise ValueError(f"Course department {row['id']}: invalid or duplicate mapping")
        department_pairs.add(pair)
    section_pairs = set()
    for row in data["CourseSection"]:
        section = indexes["DepartmentSection"].get(row["departmentsectionid"])
        ta = indexes["User"].get(row["taid"])
        pair = (row["courseid"], row["departmentsectionid"])
        if not section or (row["courseid"], section["departmentid"]) not in department_pairs:
            raise ValueError(f"Course section {row['id']}: invalid course/department")
        if not ta or ta["role"].lower() != "ta" or pair in section_pairs:
            raise ValueError(f"Course section {row['id']}: invalid TA or duplicate section")
        section_pairs.add(pair)
    for row in data["Student"]:
        university_id = str(row["universityid"])
        section = indexes["DepartmentSection"].get(row["departmentsectionid"])
        if university_id in university_ids or not university_id.strip():
            raise ValueError(f"Student {row['id']}: invalid/duplicate university ID")
        university_ids.add(university_id)
        if not section or section["departmentid"] != row["departmentid"]:
            raise ValueError(f"Student {row['id']}: section belongs to another department")
        if not 1 <= row["level"] <= 10:
            raise ValueError(f"Student {row['id']}: invalid level")
    return indexes


def sql_literal(value) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if not isinstance(value, str) or "\0" in value:
        raise ValueError("Unsupported SQL value")
    return "'" + value.replace("'", "''") + "'"


def insert(table: str, columns: tuple[str, ...], rows: list[tuple]) -> str:
    if not rows:
        return ""
    values = ",\n".join("        (" + ", ".join(sql_literal(value) for value in row) + ")" for row in rows)
    return f"    INSERT INTO {table} ({', '.join(columns)}) VALUES\n{values};\n"


def build_seed(data: dict, source_hash: str, provenance: dict) -> tuple[str, dict]:
    indexes = validate(data)
    ordered = {name: sorted(rows, key=lambda row: row["id"]) for name, rows in data.items()}
    staff_offset = max(indexes["User"]) + 1
    # Student JSON IDs are distinct from staff IDs. Preserve student IDs and allocate
    # their application user IDs in a separate range, while retaining all usernames.
    student_user_ids = {row["id"]: staff_offset + position for position, row in enumerate(ordered["Student"])}
    semesters = sorted({row["semester"] for row in data["Course"]})
    term_ids = {semester: position + 1 for position, semester in enumerate(semesters)}
    section_by_pair = {(row["courseid"], row["departmentsectionid"]): row for row in data["CourseSection"]}
    enrollment_pairs = sorted({
        (student["id"], section_by_pair[(mapping["courseid"], student["departmentsectionid"])]["id"])
        for student in data["Student"] for mapping in data["CourseDepartment"]
        if mapping["departmentid"] == student["departmentid"]
        and (mapping["courseid"], student["departmentsectionid"]) in section_by_pair
    })
    tables = {
        "departments": (('id', 'code', 'name'), [(x['id'], x['code'], x['name']) for x in ordered['Department']]),
        "department_sections": (('id', 'department_id', 'number'), [(x['id'], x['departmentid'], x['number']) for x in ordered['DepartmentSection']]),
        "app_users": (('id', 'username', 'full_name', 'email', 'role'),
            [(x['id'], x['username'], x['fullname'], x.get('email'), x['role'].lower()) for x in ordered['User']]
            + [(student_user_ids[x['id']], x['username'], x['fullname'], None, 'student') for x in ordered['Student']]),
        "students": (('id', 'user_id', 'university_id', 'level', 'department_id', 'department_section_id'),
            [(x['id'], student_user_ids[x['id']], str(x['universityid']), x['level'], x['departmentid'], x['departmentsectionid']) for x in ordered['Student']]),
        "academic_terms": (('id', 'code', 'name'), [(term_ids[s], f'legacy-semester-{s}', f'Imported semester {s}') for s in semesters]),
        "courses": (('id', 'code', 'name', 'level', 'legacy_semester'), [(x['id'], x['code'], x['name'], x['level'], x['semester']) for x in ordered['Course']]),
        "course_departments": (('id', 'course_id', 'department_id'), [(x['id'], x['courseid'], x['departmentid']) for x in ordered['CourseDepartment']]),
        "course_offerings": (('id', 'course_id', 'term_id', 'doctor_user_id'), [(x['id'], x['id'], term_ids[x['semester']], x['doctorid']) for x in ordered['Course']]),
        "course_sections": (('id', 'offering_id', 'course_id', 'department_id', 'department_section_id', 'ta_user_id'),
            [(x['id'], x['courseid'], x['courseid'], indexes['DepartmentSection'][x['departmentsectionid']]['departmentid'], x['departmentsectionid'], x['taid']) for x in ordered['CourseSection']]),
        "enrollments": (('id', 'student_id', 'offering_id', 'course_section_id'),
            [(position + 1, student_id, indexes['CourseSection'][section_id]['courseid'], section_id)
             for position, (student_id, section_id) in enumerate(enrollment_pairs)]),
    }
    counts = {table: len(rows) for table, (_, rows) in tables.items()}
    role_counts = {role: sum(row[4] == role for row in tables['app_users'][1]) for role in ('admin', 'doctor', 'ta', 'student')}
    manifest = {"source_hash": source_hash, "sources": provenance, "counts": counts, "roles": role_counts,
        "notes": ["Original IDs retained for staff, students, courses, department sections, and course sections.",
            "Student app-user IDs allocated above the highest staff ID; names are stored once in app_users.",
            "Enrollments regenerated from CourseDepartment + matching CourseSection, as in DbSeeder.GenerateEnrollments.",
            "Seed contains semester 2 but no year or term dates; legacy-semester-2 is an explicit import placeholder.",
            "No passwords, artificial GPA/contact data, attendance records, or grades were imported."]}
    manifest['data_checksums'] = {
        table: {'columns': list(columns), 'sha256': hashlib.sha256(
            json.dumps(rows, ensure_ascii=False, separators=(',', ':')).encode('utf-8')).hexdigest()}
        for table, (columns, rows) in tables.items()
    }
    body = "".join(insert(table, columns, rows) for table, (columns, rows) in tables.items())
    for table in tables:
        body += f"    PERFORM setval(pg_get_serial_sequence('attendance.{table}', 'id'), GREATEST((SELECT max(id) FROM {table}), 1), true);\n"
    body += insert('seed_imports', ('source_hash', 'source_description', 'counts'),
        [(source_hash, '.NET Seeding/*.json + DbSeeder.GenerateEnrollments', json.dumps(counts, sort_keys=True))])
    tag = "$seed_" + source_hash[:16] + "$"
    if tag in body:
        raise ValueError("Seed data collides with SQL block delimiter")
    sql = ("-- Generated by prepare_seed.py from original .NET JSON, not Flutter mock data.\n"
        "-- UTF-8; contains student identities. Keep within the authorized project.\n"
        "BEGIN;\nSET LOCAL search_path TO attendance, public;\nSET LOCAL standard_conforming_strings = on;\n"
        f"DO {tag}\nBEGIN\n"
        f"    IF EXISTS (SELECT 1 FROM seed_imports WHERE source_hash = '{source_hash}') THEN RETURN; END IF;\n"
        "    IF EXISTS (SELECT 1 FROM app_users) OR EXISTS (SELECT 1 FROM departments)\n"
        "        OR EXISTS (SELECT 1 FROM courses) OR EXISTS (SELECT 1 FROM seed_imports) THEN\n"
        "        RAISE EXCEPTION 'Seed requires an empty academic database; existing data was not modified';\n"
        "    END IF;\n" + body + f"END;\n{tag};\nCOMMIT;\n")
    return sql, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--output', type=Path, default=HERE)
    args = parser.parse_args()
    data, source_hash, provenance = read_sources(args.source.resolve())
    sql, manifest = build_seed(data, source_hash, provenance)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / '002_seed.sql').write_text(sql, encoding='utf-8', newline='\n')
    (args.output / 'seed_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(manifest['counts'], indent=2))
    print(f"Source fingerprint: {source_hash}")


if __name__ == '__main__':
    main()
