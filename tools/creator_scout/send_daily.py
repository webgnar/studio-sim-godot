#!/usr/bin/env python3
"""Send the next approved creator their Steam key email (one per run).

    python3 send_daily.py                 # dry run: shows what would be sent, sends nothing
    python3 send_daily.py --send          # really sends, then records it in sent_log.json

Files (keep them in a PRIVATE repo, they hold creators' email addresses):
    queue.json     [{"channel_id", "creator", "email", "personal_line", "approved": true}, ...] in send order
    sent_log.json  [{"channel_id", "email", "date", "key_number"}, ...]  written by this script

Environment (GitHub Actions secrets):
    GMAIL_ADDRESS        the address the email comes from (replies go there)
    GMAIL_APP_PASSWORD   a Google app password for that address
    STEAM_KEYS           one key per line. The log only records which key number was used, never the key.
    FROM_NAME            optional display name, default "Zack (Studio Sim)"
    BCC                  optional address that gets a copy of every email

Never sends the same creator or email twice, never reuses a key, and stops
cleanly when the queue or the keys run out.
"""
import argparse
import datetime
import html
import json
import os
import re
import smtplib
import sys
from email.message import EmailMessage
from email.utils import formataddr, make_msgid

HERE = os.path.dirname(os.path.abspath(__file__))
SUBJECT = "(STEAM KEY) \U0001F3A8 Play Studio Sim: the painting game where you make abstract art out of stickers"


def load(path, default):
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else default


def plain_text(body_html):
    t = re.sub(r"(?is)<(head|script|style).*?</\1>|<!--.*?-->", "", body_html)
    t = re.sub(r'(?i)<img [^>]*alt="([^"]*)"[^>]*>', r"\1", t)
    t = re.sub(r"(?i)<br\s*/?>", "\n", t)
    t = re.sub(r"(?i)</(p|tr|h\d|div)>", "\n", t)
    t = re.sub(r'(?i)<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', r"\2 (\1)", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = html.unescape(t)
    return re.sub(r"\n\s*\n\s*\n+", "\n\n", "\n".join(l.strip() for l in t.splitlines())).strip() + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--send", action="store_true", help="really send (default is a dry run)")
    ap.add_argument("--queue", default="queue.json")
    ap.add_argument("--log", default="sent_log.json")
    ap.add_argument("--template", default=os.path.join(HERE, "email_template.html"))
    args = ap.parse_args()

    queue = load(args.queue, [])
    log = load(args.log, [])
    keys = [k.strip() for k in os.environ.get("STEAM_KEYS", "").splitlines() if k.strip()]
    done_ids = {e["channel_id"] for e in log}
    done_emails = {e["email"].lower() for e in log}
    used = {e["key_number"] for e in log}

    nxt = next((q for q in queue if q.get("approved") and q.get("email") and q["channel_id"] not in done_ids
                and q["email"].lower() not in done_emails), None)
    left = sum(1 for q in queue if q.get("approved") and q.get("email") and q["channel_id"] not in done_ids)
    print(f"{len(log)} sent so far, {left} approved creators waiting, {len(keys) - len(used)} of {len(keys)} keys unused")
    if not nxt:
        print("Nothing approved to send. Approve more creators in queue.json.")
        return
    key_number = next((i for i in range(1, len(keys) + 1) if i not in used), None)
    if key_number is None:
        print("Out of Steam keys, so nothing was sent. Add more to the STEAM_KEYS secret to keep going.")
        if args.send:
            return
        key = "XXXXX-XXXXX-XXXXX"
        key_number = 0
    else:
        key = keys[key_number - 1]

    tpl = open(args.template, encoding="utf-8").read()
    body = (tpl.replace("{{CREATOR}}", html.escape(nxt.get("creator") or "there"))
               .replace("{{PERSONAL_LINE}}", html.escape(nxt.get("personal_line") or "I came across your channel."))
               .replace("{{STEAM_KEY}}", html.escape(key)))
    masked = body.replace(key, key[:5] + "-*****-*****") if key_number else body

    msg = EmailMessage()
    sender = os.environ.get("GMAIL_ADDRESS", "you@example.com")
    msg["From"] = formataddr((os.environ.get("FROM_NAME", "Zack (Studio Sim)"), sender))
    msg["To"] = nxt["email"]
    if os.environ.get("BCC"):
        msg["Bcc"] = os.environ["BCC"]
    msg["Subject"] = nxt.get("subject") or SUBJECT
    msg["Message-ID"] = make_msgid(domain=sender.split("@")[-1])
    msg.set_content(plain_text(body))
    msg.add_alternative(body, subtype="html")

    print(f"Next: {nxt.get('creator')} <{nxt['email']}> with key #{key_number}")
    print("Personal line:", nxt.get("personal_line"))
    if not args.send:
        print("\nDry run, nothing sent. Text version:\n")
        print(plain_text(masked))
        return

    pw = os.environ.get("GMAIL_APP_PASSWORD", "").replace(" ", "")
    if not pw or "GMAIL_ADDRESS" not in os.environ:
        sys.exit("GMAIL_ADDRESS and GMAIL_APP_PASSWORD must be set to send.")
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=60) as s:
        s.login(sender, pw)
        s.send_message(msg)
    log.append({"channel_id": nxt["channel_id"], "creator": nxt.get("creator", ""), "email": nxt["email"],
                "date": datetime.date.today().isoformat(), "key_number": key_number})
    json.dump(log, open(args.log, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"Sent to {nxt['email']} and logged.")


if __name__ == "__main__":
    main()
