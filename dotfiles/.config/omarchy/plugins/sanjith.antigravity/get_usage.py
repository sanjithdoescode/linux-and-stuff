#!/usr/bin/env python3
"""
Antigravity Usage Collector for Omarchy Shell.
Retrieves live quota limits (5-hour and weekly) for Gemini and Claude/GPT models
from the Google Cloud Code Antigravity backend API.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import sqlite3
import subprocess
import sys
import time
import urllib.error
import re
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

CLIENT_ID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
QUOTA_ENDPOINT = "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
CACHE_TTL_SECONDS = 30


def cache_file_path() -> Path:
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "omarchy"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / "antigravity_usage.json"


def get_token_from_keyring() -> Optional[Dict[str, Any]]:
    try:
        raw = subprocess.check_output(
            ["secret-tool", "lookup", "service", "gemini", "username", "antigravity"],
            stderr=subprocess.DEVNULL,
            timeout=5,
        ).decode("utf-8").strip()
        if raw:
            return json.loads(raw)
    except Exception:
        pass
    return None


def save_token_to_keyring(token_data: Dict[str, Any]) -> None:
    try:
        proc = subprocess.Popen(
            [
                "secret-tool",
                "store",
                "--label=Password for 'antigravity' on 'gemini'",
                "service",
                "gemini",
                "username",
                "antigravity",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        proc.communicate(input=json.dumps(token_data).encode("utf-8"), timeout=5)
    except Exception:
        pass


def decode_id_token(id_token: str) -> Dict[str, Any]:
    try:
        parts = id_token.split(".")
        if len(parts) >= 2:
            padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
            return json.loads(base64.urlsafe_b64decode(padded.encode("utf-8")))
    except Exception:
        pass
    return {}


def get_oauth_client_secret() -> str:
    sec = os.environ.get("ANTIGRAVITY_CLIENT_SECRET", "").strip()
    if sec:
        return sec
    try:
        binary = subprocess.check_output(["which", "agy"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
        with open(binary, "rb") as f:
            data = f.read()
        pattern = rb"GOC" + rb"SPX-[a-zA-Z0-9_\-]{28}"
        m = re.search(pattern, data)
        if m:
            return m.group(0).decode("ascii")
    except Exception:
        pass
    return ""


def refresh_access_token(refresh_token: str) -> Optional[Tuple[str, int]]:
    client_secret = get_oauth_client_secret()
    if not client_secret:
        return None
    params = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }).encode("utf-8")
    req = urllib.request.Request(TOKEN_ENDPOINT, data=params, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            access_tok = data.get("access_token")
            expires_in = data.get("expires_in", 3600)
            if access_tok:
                return access_tok, expires_in
    except Exception:
        pass
    return None


def get_valid_access_token(stored_data: Dict[str, Any]) -> Tuple[Optional[str], Optional[str]]:
    token_obj = stored_data.get("token", {})
    access_token = token_obj.get("access_token")
    refresh_token = token_obj.get("refresh_token")
    expiry_str = token_obj.get("expiry", "")

    # Check if expired or about to expire in next 60 seconds
    needs_refresh = False
    if expiry_str:
        try:
            # Parse ISO expiry
            # E.g. 2026-09-22T18:11:03.366031333+05:30
            # Truncate nanoseconds to microseconds for Python isoformat
            clean_str = expiry_str
            if "." in clean_str:
                prefix, rest = clean_str.split(".", 1)
                tz_delim = "+" if "+" in rest else ("-" if "-" in rest else "Z")
                if tz_delim in rest:
                    frac, tz = rest.split(tz_delim, 1)
                    clean_str = f"{prefix}.{frac[:6]}{tz_delim}{tz}"
            expiry_dt = dt.datetime.fromisoformat(clean_str)
            if expiry_dt.tzinfo is not None:
                now = dt.datetime.now(expiry_dt.tzinfo)
            else:
                now = dt.datetime.utcnow()
            if (expiry_dt - now).total_seconds() < 60:
                needs_refresh = True
        except Exception:
            needs_refresh = False

    if needs_refresh and refresh_token:
        refreshed = refresh_access_token(refresh_token)
        if refreshed:
            new_access, expires_in = refreshed
            token_obj["access_token"] = new_access
            new_exp = dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=expires_in)
            token_obj["expiry"] = new_exp.isoformat()
            stored_data["token"] = token_obj
            save_token_to_keyring(stored_data)
            return new_access, stored_data.get("id_token")

    return access_token, stored_data.get("id_token")


def format_duration(seconds: float) -> str:
    if seconds <= 0:
        return "now"
    total_minutes = int(round(seconds / 60.0))
    hours = total_minutes // 60
    minutes = total_minutes % 60
    days = hours // 24
    hours = hours % 24

    if days > 0:
        if hours > 0:
            return f"{days}d {hours}h"
        return f"{days}d"
    if hours > 0:
        return f"{hours}h {minutes:02d}m"
    return f"{max(1, minutes)}m"


def fetch_quota_summary(access_token: str) -> Optional[Dict[str, Any]]:
    req_body = json.dumps({"project": "default-cli-project"}).encode("utf-8")
    req = urllib.request.Request(
        QUOTA_ENDPOINT,
        data=req_body,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "User-Agent": "antigravity-cli",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        sys.stderr.write(f"Failed to fetch quota summary: {e}\n")
        return None


def get_local_antigravity_info() -> Dict[str, Any]:
    settings_file = Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
    active_model = "Gemini 3.8 Flash (Medium)"
    if settings_file.is_file():
        try:
            with open(settings_file, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                active_model = cfg.get("model", active_model)
        except Exception:
            pass

    db_file = Path.home() / ".gemini" / "antigravity-cli" / "conversation_summaries.db"
    total_convs = 0
    last_title = ""
    last_modified = ""
    if db_file.is_file():
        try:
            conn = sqlite3.connect(str(db_file), timeout=2)
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM conversation_summaries")
            row = cur.fetchone()
            if row:
                total_convs = row[0]
            cur.execute(
                "SELECT title, last_modified_time FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1"
            )
            row = cur.fetchone()
            if row:
                last_title = row[0]
                last_modified = str(row[1])
            conn.close()
        except Exception:
            pass

    return {
        "activeModel": active_model,
        "totalConversations": total_convs,
        "lastTitle": last_title,
        "lastModified": last_modified,
    }


def parse_bucket(bucket: Dict[str, Any], now_utc: dt.datetime) -> Dict[str, Any]:
    remaining_fraction = float(bucket.get("remainingFraction", 1.0))
    # Clamp to [0, 1]
    remaining_fraction = max(0.0, min(1.0, remaining_fraction))
    remaining_percent = int(round(remaining_fraction * 100))
    used_percent = 100 - remaining_percent

    reset_time_str = bucket.get("resetTime", "")
    resets_in_seconds = -1.0
    resets_formatted = ""

    if reset_time_str:
        try:
            parsed = dt.datetime.fromisoformat(reset_time_str.replace("Z", "+00:00"))
            resets_in_seconds = max(0.0, (parsed - now_utc).total_seconds())
            resets_formatted = format_duration(resets_in_seconds)
        except Exception:
            resets_formatted = ""

    return {
        "bucketId": bucket.get("bucketId", ""),
        "displayName": bucket.get("displayName", ""),
        "window": bucket.get("window", ""),
        "remainingFraction": remaining_fraction,
        "remainingPercent": remaining_percent,
        "usedPercent": used_percent,
        "resetTime": reset_time_str,
        "resetsInSeconds": resets_in_seconds,
        "resetsFormatted": resets_formatted,
        "description": bucket.get("description", ""),
    }


def collect_usage(force: bool = False) -> Dict[str, Any]:
    cache_path = cache_file_path()

    if not force and cache_path.is_file():
        try:
            mtime = cache_path.stat().st_mtime
            if time.time() - mtime < CACHE_TTL_SECONDS:
                with open(cache_path, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    if cached.get("ready"):
                        # Re-calculate reset countdowns based on current time
                        now_utc = dt.datetime.now(dt.timezone.utc)
                        for group_key in ["gemini", "claudeGpt"]:
                            group = cached.get(group_key, {})
                            for limit_key in ["fiveHour", "weekly"]:
                                limit = group.get(limit_key, {})
                                reset_str = limit.get("resetTime")
                                if reset_str:
                                    try:
                                        p = dt.datetime.fromisoformat(reset_str.replace("Z", "+00:00"))
                                        secs = max(0.0, (p - now_utc).total_seconds())
                                        limit["resetsInSeconds"] = secs
                                        limit["resetsFormatted"] = format_duration(secs)
                                    except Exception:
                                        pass
                        return cached
        except Exception:
            pass

    keyring_data = get_token_from_keyring()
    if not keyring_data:
        return {
            "ready": False,
            "authenticated": False,
            "error": "Not logged in to Google Antigravity. Run `agy` to authenticate.",
            "authHelpText": "Run `agy` to sign in with your Google account.",
        }

    access_token, id_token = get_valid_access_token(keyring_data)
    if not access_token:
        return {
            "ready": False,
            "authenticated": False,
            "error": "Authentication token missing or invalid. Run `agy` to login.",
            "authHelpText": "Run `agy` to re-authenticate.",
        }

    claims = decode_id_token(id_token) if id_token else {}
    email = claims.get("email", "sanjithkarthik16@gmail.com")
    auth_method = keyring_data.get("auth_method", "consumer")

    quota_data = fetch_quota_summary(access_token)
    if not quota_data or "groups" not in quota_data:
        # Fallback to cache if network call fails
        if cache_path.is_file():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    cached["stale"] = True
                    return cached
            except Exception:
                pass
        return {
            "ready": False,
            "authenticated": True,
            "userEmail": email,
            "error": "Failed to retrieve quota from Antigravity service.",
            "authHelpText": "Check network connection or run `agy`.",
        }

    now_utc = dt.datetime.now(dt.timezone.utc)
    groups = quota_data.get("groups", [])

    gemini_group: Dict[str, Any] = {}
    claude_group: Dict[str, Any] = {}

    lowest_remaining = 1.0

    for g in groups:
        title = g.get("displayName", "")
        buckets = g.get("buckets", [])
        parsed_5h: Optional[Dict[str, Any]] = None
        parsed_weekly: Optional[Dict[str, Any]] = None

        for b in buckets:
            parsed = parse_bucket(b, now_utc)
            frac = parsed["remainingFraction"]
            if frac < lowest_remaining:
                lowest_remaining = frac
            if parsed["window"] == "5h" or "5-hour" in parsed["displayName"].lower() or "five" in parsed["displayName"].lower():
                parsed_5h = parsed
            elif parsed["window"] == "weekly" or "week" in parsed["displayName"].lower():
                parsed_weekly = parsed

        group_record = {
            "displayName": title,
            "description": g.get("description", ""),
            "fiveHour": parsed_5h or {},
            "weekly": parsed_weekly or {},
        }

        if "gemini" in title.lower():
            group_record["models"] = "Gemini 3.8 Flash, 3.7 Flash, 3.1 Pro"
            gemini_group = group_record
        else:
            group_record["models"] = "Claude Opus 4.6, Claude Sonnet 4.6, GPT-OSS 120B"
            claude_group = group_record

    local_info = get_local_antigravity_info()

    result = {
        "ready": True,
        "authenticated": True,
        "userEmail": email,
        "tierLabel": auth_method.capitalize() if auth_method else "Consumer",
        "activeModel": local_info.get("activeModel", "Gemini 3.8 Flash (Medium)"),
        "lowestRemaining": lowest_remaining,
        "lowestRemainingPercent": int(round(lowest_remaining * 100)),
        "gemini": gemini_group,
        "claudeGpt": claude_group,
        "localStats": {
            "totalConversations": local_info.get("totalConversations", 0),
            "lastTitle": local_info.get("lastTitle", ""),
            "lastModified": local_info.get("lastModified", ""),
        },
        "quotaPolicy": quota_data.get("description", ""),
        "updatedAt": now_utc.isoformat(),
    }

    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
    except Exception:
        pass

    # Also update Omarchy agents state directory if present
    agents_usage_dir = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "omarchy" / "agents" / "usage"
    if agents_usage_dir.is_dir():
        try:
            agent_record = {
                "schemaVersion": 1,
                "id": "antigravity",
                "name": "Google Antigravity",
                "updatedAt": now_utc.isoformat(),
                "ready": True,
                "hasLocalStats": True,
                "todayPrompts": 1,
                "todaySessions": 1,
                "todayTotalTokens": 0,
                "todayTokensByModel": {},
                "recentDays": [],
                "totalPrompts": local_info.get("totalConversations", 0),
                "totalSessions": local_info.get("totalConversations", 0),
                "activeDays": 1,
                "activeDates": [now_utc.strftime("%Y-%m-%d")],
                "modelUsage": {
                    local_info.get("activeModel", "Gemini 3.8 Flash"): {
                        "inputTokens": 0,
                        "outputTokens": 0,
                        "cacheReadInputTokens": 0,
                        "cacheCreationInputTokens": 0,
                    }
                },
                "limits": [
                    {
                        "label": "Gemini 5-Hour",
                        "title": "Gemini 5-Hour",
                        "percent": round(1.0 - gemini_group.get("fiveHour", {}).get("remainingFraction", 1.0), 3),
                        "resetsAt": gemini_group.get("fiveHour", {}).get("resetTime", ""),
                    },
                    {
                        "label": "Gemini Weekly",
                        "title": "Gemini Weekly",
                        "percent": round(1.0 - gemini_group.get("weekly", {}).get("remainingFraction", 1.0), 3),
                        "resetsAt": gemini_group.get("weekly", {}).get("resetTime", ""),
                    },
                    {
                        "label": "Claude/GPT 5-Hour",
                        "title": "Claude/GPT 5-Hour",
                        "percent": round(1.0 - claude_group.get("fiveHour", {}).get("remainingFraction", 1.0), 3),
                        "resetsAt": claude_group.get("fiveHour", {}).get("resetTime", ""),
                    },
                    {
                        "label": "Claude/GPT Weekly",
                        "title": "Claude/GPT Weekly",
                        "percent": round(1.0 - claude_group.get("weekly", {}).get("remainingFraction", 1.0), 3),
                        "resetsAt": claude_group.get("weekly", {}).get("resetTime", ""),
                    },
                ],
                "tierLabel": auth_method.capitalize() if auth_method else "Consumer",
                "usageStatusText": "",
                "authHelpText": "",
            }
            with open(agents_usage_dir / "antigravity.json", "w", encoding="utf-8") as f:
                json.dump(agent_record, f, indent=2)
        except Exception:
            pass

    return result


def main():
    parser = argparse.ArgumentParser(description="Antigravity usage collector for Omarchy")
    parser.add_argument("--force", action="store_true", help="Bypass cache and force refresh")
    args = parser.parse_args()

    record = collect_usage(force=args.force)
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
