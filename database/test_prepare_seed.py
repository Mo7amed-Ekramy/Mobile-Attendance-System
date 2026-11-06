"""Tests for migration-sensitive cases in the legacy seed conversion."""
import copy
import unittest

from prepare_seed import DEFAULT_SOURCE, build_seed, read_sources, sql_literal, validate


class SeedConversionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data, cls.fingerprint, cls.provenance = read_sources(DEFAULT_SOURCE)

    def test_original_seed_is_valid_and_enrollments_are_reconstructed(self):
        sql, manifest = build_seed(self.data, self.fingerprint, self.provenance)
        self.assertEqual(manifest['counts']['enrollments'], 2460)
        self.assertEqual(manifest['roles'], {'admin': 6, 'doctor': 9, 'ta': 21, 'student': 415})
        self.assertIn('legacy-semester-2', sql)
        self.assertNotIn('Doctor@123', sql)
        self.assertNotIn('gpa', sql.lower())

    def test_arabic_and_apostrophes_survive_sql_conversion(self):
        self.assertEqual(sql_literal("أحمد O'Brien"), "'أحمد O''Brien'")
        self.assertEqual(sql_literal('20720236007'), "'20720236007'")
        with self.assertRaises(ValueError):
            sql_literal('bad\0value')

    def test_student_section_from_other_department_is_rejected(self):
        data = copy.deepcopy(self.data)
        student = data['Student'][0]
        student['departmentsectionid'] = next(row['id'] for row in data['DepartmentSection'] if row['departmentid'] != student['departmentid'])
        with self.assertRaisesRegex(ValueError, 'another department'):
            validate(data)

    def test_staff_assignment_requires_the_correct_role(self):
        data = copy.deepcopy(self.data)
        doctor_id = data['Course'][0]['doctorid']
        next(row for row in data['User'] if row['id'] == doctor_id)['role'] = 'TA'
        with self.assertRaisesRegex(ValueError, 'not a doctor'):
            validate(data)

    def test_duplicate_case_insensitive_usernames_are_rejected(self):
        data = copy.deepcopy(self.data)
        data['Student'][0]['username'] = data['User'][0]['username'].upper()
        with self.assertRaisesRegex(ValueError, 'Duplicate username'):
            validate(data)

    def test_output_is_deterministic_independent_of_seed_row_order(self):
        baseline = build_seed(self.data, self.fingerprint, self.provenance)
        reordered = {name: list(reversed(rows)) for name, rows in self.data.items()}
        self.assertEqual(build_seed(reordered, self.fingerprint, self.provenance), baseline)


if __name__ == '__main__':
    unittest.main()
