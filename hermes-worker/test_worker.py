import os
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SECRET_KEY", "sb_secret_test")

import worker


class WorkerTests(unittest.TestCase):
    def tearDown(self):
        worker.SUPABASE_SECRET_KEY = "sb_secret_test"

    def test_new_secret_key_is_never_sent_as_bearer(self):
        request_headers = worker.headers()
        self.assertEqual(request_headers["apikey"], "sb_secret_test")
        self.assertNotIn("Authorization", request_headers)

    def test_legacy_service_role_jwt_keeps_authorization_header(self):
        worker.SUPABASE_SECRET_KEY = "eyJlegacy"
        request_headers = worker.headers()
        self.assertEqual(request_headers["Authorization"], "Bearer eyJlegacy")

    @patch("worker.requests.post")
    def test_claim_job_returns_first_queued_job(self, post: Mock):
        response = Mock()
        response.json.return_value = [{"id": "job-1", "kind": "daily_plan"}]
        post.return_value = response

        claimed = worker.claim_job()

        self.assertEqual(claimed["id"], "job-1")
        response.raise_for_status.assert_called_once()
        post.assert_called_once()

    @patch("worker.subprocess.run")
    def test_run_hermes_uses_isolated_profile_without_a_shell(self, run: Mock):
        run.return_value = Mock(returncode=0, stdout="Rascunho pronto", stderr="")

        output = worker.run_hermes({
            "id": "job-1",
            "kind": "reply_draft",
            "input": {"message": "O quadro vai abaixo."},
        })

        self.assertEqual(output, "Rascunho pronto")
        command = run.call_args.args[0]
        options = run.call_args.kwargs
        self.assertEqual(command[0], worker.HERMES_COMMAND)
        self.assertEqual(command[1], "-z")
        self.assertIn("read-only", command[2])
        self.assertEqual(options["env"]["HERMES_HOME"], worker.HERMES_PROFILE_HOME)
        self.assertNotIn("shell", options)

    @patch("worker.subprocess.run")
    def test_run_hermes_reports_cli_failure(self, run: Mock):
        run.return_value = Mock(returncode=1, stdout="", stderr="perfil inválido")

        with self.assertRaisesRegex(RuntimeError, "perfil inválido"):
            worker.run_hermes({"id": "job-2", "kind": "daily_plan", "input": {}})


if __name__ == "__main__":
    unittest.main()
