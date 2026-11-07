"""Unit tests for bin/claude-vault that run anywhere (no macOS Keychain needed).

`security` is never executed: subprocess.run is replaced with a fake that
records every call, so the tests check what *would* be sent to it.

    python3 -m unittest discover -s tests      # or: python3 -m pytest tests
"""

import importlib.machinery
import importlib.util
import io
import os
import subprocess
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

VAULT = Path(__file__).resolve().parents[1] / "bin" / "claude-vault"


def load_vault():
    loader = importlib.machinery.SourceFileLoader("claude_vault", str(VAULT))
    spec = importlib.util.spec_from_loader("claude_vault", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class FakeSecurity:
    """Stands in for subprocess.run; emulates `security -i` add + find."""

    def __init__(self, vault):
        self.vault = vault
        self.calls = []
        self.stored = {}
        self.mangle_stdin = False  # simulate an unexpected `security -i` parse

    def __call__(self, argv, **kw):
        self.calls.append((list(argv), kw.get("input")))
        if argv[:2] == ["security", "-i"]:
            args = self.parse(kw["input"])
            assert args[0] == "add-generic-password", args
            value = args[args.index("-w") + 1]
            self.stored[args[args.index("-s") + 1]] = value + "~" if self.mangle_stdin else value
            return subprocess.CompletedProcess(argv, 0, "", "")
        if argv[:2] == ["security", "add-generic-password"]:  # the original argv method
            self.stored[argv[argv.index("-s") + 1]] = argv[argv.index("-w") + 1]
            return subprocess.CompletedProcess(argv, 0, "", "")
        if argv[:2] == ["security", "find-generic-password"]:
            svc = argv[argv.index("-s") + 1]
            if svc in self.stored:
                return subprocess.CompletedProcess(argv, 0, self.stored[svc] + "\n", "")
            return subprocess.CompletedProcess(argv, 44, "", "not found")
        raise AssertionError(f"unexpected command {argv}")

    @staticmethod
    def parse(line):
        """Model of the `security -i` line splitter: whitespace separates,
        double quotes group, backslash takes the next character literally."""
        assert line.endswith("\n") and line.count("\n") == 1
        args, cur, quoted, esc, have = [], "", False, False, False
        for c in line[:-1]:
            if esc:
                cur, esc = cur + c, False
            elif c == "\\":
                esc, have = True, True
            elif c == '"':
                quoted, have = not quoted, True
            elif c.isspace() and not quoted:
                if have:
                    args.append(cur)
                cur, have = "", False
            else:
                cur, have = cur + c, True
        assert not quoted and not esc
        if have:
            args.append(cur)
        return args


SECRETS = [
    "s3cr3t-value",
    'with "double" quotes',
    "back\\slash\\\\double",
    "spaces  and\ttab",
    "single 'quote' $HOME `cmd` ; | &",
    '{"host":"db","password":"p\\"w"}',
]


class KcSetTest(unittest.TestCase):
    def setUp(self):
        self.vault = load_vault()
        self.fake = FakeSecurity(self.vault)
        patcher = mock.patch.object(self.vault.subprocess, "run", self.fake)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_secret_absent_from_argv_and_present_on_stdin(self):
        for secret in SECRETS:
            with self.subTest(secret=secret):
                self.fake.calls.clear()
                self.vault.kc_set("entry", secret)
                write = [c for c in self.fake.calls if c[0][:2] == ["security", "-i"]]
                self.assertEqual(len(write), 1)
                for argv, _ in self.fake.calls:
                    for arg in argv:
                        self.assertNotIn(secret, arg)
                stdin = write[0][1]
                self.assertIsNotNone(stdin)
                parsed = FakeSecurity.parse(stdin)
                self.assertEqual(parsed[parsed.index("-w") + 1], secret)
                self.assertEqual(parsed[parsed.index("-s") + 1], "claude-vault.entry")
                self.assertIn("-U", parsed)

    def test_garbled_stdin_write_falls_back_to_the_original_method(self):
        self.fake.mangle_stdin = True
        with redirect_stderr(io.StringIO()) as err:
            self.vault.kc_set("entry", "s3cr3t-value")
        self.assertEqual(self.fake.stored["claude-vault.entry"], "s3cr3t-value")
        self.assertIn("original method", err.getvalue())

    def test_value_with_newline_uses_the_original_method(self):
        with redirect_stderr(io.StringIO()):
            self.vault.kc_set("entry", "line1\nline2")
        self.assertEqual(self.fake.stored["claude-vault.entry"], "line1\nline2")
        self.assertFalse(any(c[0][:2] == ["security", "-i"] for c in self.fake.calls))

    def test_failure_of_both_methods_exits(self):
        def failing(argv, **kw):
            return subprocess.CompletedProcess(argv, 1, "", "SecKeychainItemCreate: denied")
        with mock.patch.object(self.vault.subprocess, "run", failing), redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                self.vault.kc_set("entry", "x")
        self.assertIn("denied", str(cm.exception))

    def test_readback_mismatch_after_fallback_exits(self):
        def mangling(argv, **kw):
            if argv[:2] in (["security", "-i"], ["security", "add-generic-password"]):
                return subprocess.CompletedProcess(argv, 0, "", "")
            return subprocess.CompletedProcess(argv, 0, "mangled\n", "")
        with mock.patch.object(self.vault.subprocess, "run", mangling), redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self.vault.kc_set("entry", "x")


class GetWarningTest(unittest.TestCase):
    def setUp(self):
        self.vault = load_vault()
        self.vault.kc_get = lambda name: "the-value"
        self.vault.load_index = lambda: {"e": {"type": "plain"}}

    def run_get(self, env):
        out, err = io.StringIO(), io.StringIO()   # StringIO.isatty() is False
        with mock.patch.dict(os.environ, env, clear=False), \
                redirect_stdout(out), redirect_stderr(err):
            self.vault.cmd_get("e", None)
        return out.getvalue(), err.getvalue()

    def test_non_tty_get_warns_on_stderr(self):
        os.environ.pop("CLAUDE_VAULT_QUIET", None)
        out, err = self.run_get({})
        self.assertEqual(out, "the-value\n")
        self.assertIn("claude-vault exec e", err)
        self.assertNotIn("the-value", err)

    def test_quiet_env_silences_warning(self):
        out, err = self.run_get({"CLAUDE_VAULT_QUIET": "1"})
        self.assertEqual(out, "the-value\n")
        self.assertEqual(err, "")


if __name__ == "__main__":
    unittest.main()
