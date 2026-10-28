"""The feedback report's verdicts: enough answers, target, and allergen alerts."""

from scripts.eval_report import MIN_ANSWERS, assess, render
from src.domain.feedback import summarize_feedback


def _summary(right: int, wrong: int, issue: str = "wrong_nutrition"):
    rows = [{"accurate": True, "issues": []}] * right
    rows += [{"accurate": False, "issues": [issue]}] * wrong
    return summarize_feedback(rows)


def test_too_few_answers_is_not_a_verdict():
    verdict, failed = assess(_summary(3, 7))
    assert "Not enough answers" in verdict and not failed


def test_below_target_fails():
    verdict, failed = assess(_summary(MIN_ANSWERS, MIN_ANSWERS))
    assert verdict.startswith("BELOW TARGET") and failed


def test_on_target_passes():
    verdict, failed = assess(_summary(90, 10))
    assert verdict.startswith("On target") and not failed


def test_a_single_missed_allergen_always_alerts():
    verdict, failed = assess(_summary(99, 1, issue="missed_allergen"))
    assert verdict.startswith("ALERT") and failed


def test_render_lists_issues_most_common_first():
    out = render(summarize_feedback(
        [{"accurate": False, "issues": ["score_unfair"]}] * 2
        + [{"accurate": False, "issues": ["wrong_product", "score_unfair"]}]), 7)
    assert out.index("Score felt wrong") < out.index("Wrong product identified")
    assert "Accuracy:       0.0%" in out


def test_no_answers_shows_no_made_up_rate():
    out = render(summarize_feedback([]), 7)
    assert "Accuracy" not in out and "Answers:        0" in out
