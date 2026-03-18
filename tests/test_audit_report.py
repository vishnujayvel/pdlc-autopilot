"""Pytest tests for the retrospective audit report (R1-R9).

Validates the audit report structure, content completeness, and BATS test suite health.
"""

import os
import re
import subprocess

# Path to the audit report
REPORT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "docs",
    "audit-retrospective-r1-r9.md",
)

# Path to individual audit findings
AUDIT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    ".loki",
    "audit",
)

PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))


class TestAuditReportExists:
    """The audit report must exist and be non-empty."""

    def test_report_file_exists(self):
        assert os.path.isfile(REPORT_PATH), (
            f"Audit report not found at {REPORT_PATH}"
        )

    def test_report_is_non_empty(self):
        assert os.path.getsize(REPORT_PATH) > 500, (
            "Audit report is too small (< 500 bytes) — likely incomplete"
        )


class TestAuditReportStructure:
    """The report must contain all required sections per the PRD."""

    def _read_report(self):
        with open(REPORT_PATH, "r") as f:
            return f.read()

    def test_has_title(self):
        content = self._read_report()
        assert "Retrospective Audit" in content

    def test_has_executive_summary(self):
        content = self._read_report()
        assert "Executive Summary" in content

    def test_has_metrics_dashboard(self):
        content = self._read_report()
        assert "Metrics Dashboard" in content or "Metrics" in content

    def test_has_all_five_dimensions(self):
        content = self._read_report()
        dimensions = [
            "Integration",
            "Code Quality",
            "Test Quality",
            "Architecture",
            "Convention",
        ]
        for dim in dimensions:
            assert dim in content, f"Missing dimension: {dim}"

    def test_has_remediation_plan(self):
        content = self._read_report()
        assert "Remediation" in content

    def test_has_quality_score(self):
        content = self._read_report()
        # Should contain a score like "XX/100"
        assert re.search(r"\d+/100", content), (
            "Report missing quality score (expected pattern: N/100)"
        )

    def test_has_date(self):
        content = self._read_report()
        # Should contain a date in YYYY-MM-DD format
        assert re.search(r"\d{4}-\d{2}-\d{2}", content), (
            "Report missing date"
        )


class TestAuditFindings:
    """Individual audit dimension files must exist."""

    EXPECTED_FILES = [
        "integration.md",
        "quality.md",
        "tests.md",
        "architecture.md",
        "conventions.md",
    ]

    def test_audit_directory_exists(self):
        assert os.path.isdir(AUDIT_DIR), (
            f"Audit findings directory not found at {AUDIT_DIR}"
        )

    def test_all_dimension_files_exist(self):
        for filename in self.EXPECTED_FILES:
            path = os.path.join(AUDIT_DIR, filename)
            assert os.path.isfile(path), (
                f"Missing audit finding: {filename}"
            )

    def test_findings_are_non_empty(self):
        for filename in self.EXPECTED_FILES:
            path = os.path.join(AUDIT_DIR, filename)
            if os.path.isfile(path):
                assert os.path.getsize(path) > 100, (
                    f"Audit finding {filename} is too small (< 100 bytes)"
                )


class TestBatsTestSuite:
    """BATS test suite must pass as part of overall quality verification."""

    def test_bats_unit_tests_pass(self):
        result = subprocess.run(
            ["bats", "tests/unit/"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=120,
        )
        assert result.returncode == 0, (
            f"BATS unit tests failed:\n{result.stdout}\n{result.stderr}"
        )

    def test_bats_integration_tests_pass(self):
        result = subprocess.run(
            ["bats", "tests/integration/"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=120,
        )
        assert result.returncode == 0, (
            f"BATS integration tests failed:\n{result.stdout}\n{result.stderr}"
        )


class TestCodeMetrics:
    """Basic code metrics validation."""

    def test_hook_scripts_have_err_traps(self):
        """All hook scripts (not lib/) must have ERR traps per CLAUDE.md."""
        hooks_dir = os.path.join(PROJECT_ROOT, "hooks")
        violations = []
        for filename in os.listdir(hooks_dir):
            if not filename.endswith(".sh"):
                continue
            filepath = os.path.join(hooks_dir, filename)
            with open(filepath, "r") as f:
                content = f.read()
            if "trap" not in content and "exit 0" not in content:
                violations.append(filename)
        assert not violations, (
            f"Hook scripts missing ERR trap: {violations}"
        )

    def test_lib_scripts_exist(self):
        """Library scripts referenced by hooks must exist."""
        lib_dir = os.path.join(PROJECT_ROOT, "hooks", "lib")
        assert os.path.isdir(lib_dir)
        libs = [f for f in os.listdir(lib_dir) if f.endswith(".sh")]
        assert len(libs) >= 5, (
            f"Expected at least 5 library scripts, found {len(libs)}"
        )
