#!/usr/bin/env bash
# Check every site in sites.txt. A failing site gets an open issue titled
# "DOWN: <name>" (GitHub notifies the repo owner); when it recovers, the issue
# gets a comment and is closed. Also opens "CERT: <name>" when the TLS
# certificate expires within 14 days.
set -uo pipefail

open_issue() { # title body
  if ! gh issue list --state open --search "\"$1\" in:title" --json title -q '.[].title' | grep -qxF "$1"; then
    gh issue create --title "$1" --body "$2" >/dev/null && echo "opened: $1"
  fi
}
close_issue() { # title comment
  gh issue list --state open --search "\"$1\" in:title" --json number,title -q ".[] | select(.title == \"$1\") | .number" |
    while read -r n; do gh issue close "$n" --comment "$2" >/dev/null && echo "closed: $1"; done
}

now=$(date -u '+%F %H:%M UTC')
run="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
failed=0

while read -r name url; do
  [[ -z "$name" || "$name" == \#* ]] && continue

  if out=$(curl -sS -o /dev/null -w '%{http_code}' -m 15 --retry 2 --retry-delay 10 --retry-all-errors -f "$url" 2>&1); then
    echo "ok    $name"
    close_issue "DOWN: $name" "Back up at $now."
  else
    echo "DOWN  $name: $out"
    failed=1
    open_issue "DOWN: $name" "$url failed at $now (3 tries).

\`\`\`
$out
\`\`\`
[Run]($run) · @$GITHUB_REPOSITORY_OWNER"
  fi

  host=${url#https://}; host=${host%%/*}
  if end=$(echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null); then
    end=${end#notAfter=}
    if (( $(date -d "$end" +%s) - $(date +%s) < 14 * 86400 )); then
      open_issue "CERT: $name" "The certificate for $host expires $end. certbot should have renewed it: check \`certbot renew\` on the VPS. @$GITHUB_REPOSITORY_OWNER"
    else
      close_issue "CERT: $name" "Renewed, now valid until $end."
    fi
  fi
done < sites.txt

exit $failed
