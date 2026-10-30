"""Read Swift Testing summaries across the supported Xcode toolchains."""
import re


def parse_summary(log):
    summaries = re.findall(r"Test run with (\d+) tests?(?: in (\d+) suites?)? passed", log)
    test_count = sum(int(tests) for tests, _ in summaries)
    if not summaries or test_count == 0:
        raise ValueError("No nonempty passing Swift Testing summary found.")
    # Older Swift Testing omits suite counts from its final summary.
    suite_count = (sum(int(suites) for _, suites in summaries)
                   if all(suites for _, suites in summaries)
                   else len(re.findall(r"Suite .+ passed after", log)))
    if suite_count == 0:
        raise ValueError("No passing Swift Testing suite found.")
    return test_count, suite_count
