"""Allocate whole questions using the 40/40/20 ratio and largest remainders."""

DIFFICULTIES = ('easy', 'medium', 'hard')
DIFFICULTY_LABELS = {'easy': 'سهل', 'medium': 'متوسط', 'hard': 'صعب'}


def difficulty_counts(question_count):
    weights = (2, 2, 1)
    counts = [question_count * weight // 5 for weight in weights]
    remaining = question_count - sum(counts)
    # Equal remainders favor easy, then medium, then hard.
    order = sorted(range(3), key=lambda i: (-(question_count * weights[i] % 5), i))
    for index in order[:remaining]:
        counts[index] += 1
    return dict(zip(DIFFICULTIES, counts))
