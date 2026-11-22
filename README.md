# uptime

Checks the sites in [sites.txt](sites.txt) every 5 minutes from GitHub Actions
(public repo, so the minutes are free).

- A site that fails 3 tries gets an open issue **DOWN: name**; GitHub emails
  you about it. When it's back, the issue is closed with a comment.
- A TLS certificate within 14 days of expiry gets **CERT: name**.

Add a site: one line in `sites.txt`. Run now: Actions → Check sites → Run workflow.
Scheduled runs can start a few minutes late; GitHub doesn't guarantee the interval.
