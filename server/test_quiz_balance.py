import unittest

from quiz_balance import difficulty_counts


class QuizBalanceTests(unittest.TestCase):
    def test_examples_and_rounding(self):
        expected = {1: (1, 0, 0), 2: (1, 1, 0), 3: (1, 1, 1), 4: (2, 1, 1),
                    5: (2, 2, 1), 6: (3, 2, 1), 7: (3, 3, 1), 10: (4, 4, 2), 60: (24, 24, 12)}
        for quantity, counts in expected.items():
            with self.subTest(quantity=quantity):
                self.assertEqual(tuple(difficulty_counts(quantity).values()), counts)

    def test_every_supported_quantity_preserves_total_and_stays_within_one_question_of_ratio(self):
        for quantity in range(1, 101):
            counts = difficulty_counts(quantity)
            self.assertEqual(sum(counts.values()), quantity)
            for level, weight in zip(('easy', 'medium', 'hard'), (2, 2, 1)):
                self.assertLess(abs(counts[level] - quantity * weight / 5), 1)
