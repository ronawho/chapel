import time
import re

# TODO this is a simplifed version from start_test. Move into common code and reuse that
def create_summary(tmp_log_file):
    date_str = time.strftime("%y%m%d.%H%M%S")
    future_marker = r"^Future"
    suppress_marker = r"^Suppress"
    error_marker = r"^\[Error"
    success_marker = r"\[Success matching"
    warning_marker = r"^\[Warning"
    passing_suppressions_marker = ("{0}.*{1}"
            .format(suppress_marker, success_marker))
    passing_futures_marker = "{0}.*{1}".format(future_marker, success_marker)
    success_marker = "^" + success_marker
    skip_stdin_redirect_marker = r"^\[Skipping test with .stdin input"

    failures = 0
    successes = 0
    futures = 0
    warnings = 0
    passing_suppressions = 0
    passing_futures = 0
    skip_stdin_redirects = 0
    failure_summary = ""
    suppression_summary = ""
    future_summary = ""
    warning_summary = ""
    summary = "[Test Summary - {0}]\n".format(date_str)

    # scan line-by-line, logging failures, warnings, etc.. and updating counts
    with open(tmp_log_file, "r") as log:
        for line in log:
            if re.search(error_marker, line, flags=re.M):
                failure_summary += line
                failures += 1
            elif re.search(suppress_marker, line, flags=re.M):
                suppression_summary += line
            elif re.search(future_marker, line, flags=re.M):
                future_summary += line
                futures += 1
            elif re.search(warning_marker, line, flags=re.M):
                warning_summary += line
                warnings += 1
            elif re.search(success_marker, line, flags=re.M):
                successes += 1
            if re.search(passing_suppressions_marker, line, flags=re.M):
                passing_suppressions += 1
            elif re.search(passing_futures_marker, line, flags=re.M):
                passing_futures += 1
            elif re.search(skip_stdin_redirect_marker, line, flags=re.M):
                skip_stdin_redirects += 1

    # compile summary
    summary += failure_summary
    summary += suppression_summary
    summary += future_summary
    summary += warning_summary

    if skip_stdin_redirects > 0:
        logger.write("[Skipped {0} tests with .stdin input]"
                .format(skip_stdin_redirects))

    summary += ("[Summary: #Successes = {0} | #Failures = {1} | #Futures = {2} "
            "| #Warnings = {3} ]\n"
            .format(successes, failures, futures, warnings))
    summary += ("[Summary: #Passing Suppressions = {0} | "
            "#Passing Futures = {1} ]\n"
            .format(passing_suppressions, passing_futures))
    summary += "[END]\n"

    return summary
    #with open(tmp_summary_file, "w") as log_summary:
    #    log_summary.write(summary)

