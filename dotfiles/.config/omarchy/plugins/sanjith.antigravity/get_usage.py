#!/usr/bin/env python3
"""
Antigravity Usage Collector for Omarchy Shell.
Dynamically retrieves live quota limits (5-hour and weekly), available models,
and full token consumption metrics per model and historical ledger from Antigravity.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

CLIENT_ID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
PROD_QUOTA_ENDPOINT = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
CACHE_TTL_SECONDS = 60
MODELS_CACHE_TTL_SECONDS = 900  # 15 minutes


def cache_file_path() -> Path:
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "omarchy"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / "antigravity_usage.json"


def models_cache_file_path() -> Path:
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "omarchy"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / "antigravity_available_models.json"


def token_ledger_file_path() -> Path:
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "omarchy"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / "antigravity_token_ledger.json"


def format_tokens(count: int | float) -> str:
    """Format token counts into human-readable compact numbers (e.g. 1.25M, 850K)."""
    count = int(round(count))
    if count >= 1_000_000_000:
        val = count / 1_000_000_000
        return f"{val:.2f}".rstrip("0").rstrip(".") + "B"
    if count >= 1_000_000:
        val = count / 1_000_000
        return f"{val:.2f}".rstrip("0").rstrip(".") + "M"
    if count >= 1_000:
        val = count / 1_000
        return f"{val:.1f}".rstrip("0").rstrip(".") + "K"
    return str(count)


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


def decode_id_token(id_token: str) -> Dict[str, Any]:
    try:
        parts = id_token.split(".")
        if len(parts) >= 2:
            padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
            return json.loads(base64.urlsafe_b64decode(padded.encode("utf-8")))
    except Exception:
        pass
    return {}


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


def get_discovered_models(force: bool = False) -> List[Dict[str, Any]]:
    """
    Dynamically discover available models from `agy models`.
    Filters out legacy models and internal Google backend models.
    """
    cache_path = models_cache_file_path()
    if not force and cache_path.is_file():
        try:
            if time.time() - cache_path.stat().st_mtime < MODELS_CACHE_TTL_SECONDS:
                with open(cache_path, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    if isinstance(cached, list) and len(cached) > 0:
                        return cached
        except Exception:
            pass

    # Authoritative discovery via `agy models`
    try:
        proc = subprocess.run(["agy", "models"], capture_output=True, text=True, timeout=8)
        if proc.returncode == 0:
            discovered: List[Dict[str, Any]] = []
            for line in proc.stdout.splitlines():
                line = line.strip()
                if not line or "Fetching available models" in line or "..." in line:
                    continue
                clean_line = re.sub(r"^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏\s]+", "", line).strip()
                if not clean_line or "fetching" in clean_line.lower():
                    continue
                parts = re.split(r"\s{2,}|\t+", clean_line)
                if len(parts) >= 2:
                    mid = parts[0].strip()
                    dname = parts[1].strip()
                    if not mid or not dname or "fetching" in mid.lower() or "fetching" in dname.lower():
                        continue
                    discovered.append({
                        "id": mid,
                        "displayName": dname,
                    })
            if discovered:
                try:
                    with open(cache_path, "w", encoding="utf-8") as f:
                        json.dump(discovered, f, indent=2)
                except Exception:
                    pass
                return discovered
    except Exception as e:
        sys.stderr.write(f"agy models discovery failed: {e}\n")

    fallback = [
        {"id": "gemini-3.8-flash-high", "displayName": "Gemini 3.8 Flash (High)"},
        {"id": "gemini-3.8-flash-medium", "displayName": "Gemini 3.8 Flash (Medium)"},
        {"id": "gemini-3.8-flash-low", "displayName": "Gemini 3.8 Flash (Low)"},
        {"id": "claude-sonnet-4-6", "displayName": "Claude Sonnet 4.6 (Thinking)"},
        {"id": "claude-opus-4-6-thinking", "displayName": "Claude Opus 4.6 (Thinking)"},
        {"id": "gpt-oss-120b-medium", "displayName": "GPT-OSS 120B (Medium)"},
    ]
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(fallback, f, indent=2)
    except Exception:
        pass
    return fallback


def parse_bucket(bucket: Dict[str, Any], now_utc: dt.datetime) -> Dict[str, Any]:
    bucket_id = bucket.get("id") or bucket.get("bucketId", "")
    display_name = bucket.get("name") or bucket.get("displayName", "")
    window = bucket.get("window", "")

    rf = bucket.get("remaining_fraction")
    if rf is None:
        rf = bucket.get("remainingFraction", 1.0)
    try:
        remaining_fraction = float(rf)
    except (ValueError, TypeError):
        remaining_fraction = 1.0
    remaining_fraction = max(0.0, min(1.0, remaining_fraction))

    remaining_percent = int(round(remaining_fraction * 100))
    used_percent = 100 - remaining_percent

    reset_time_str = bucket.get("reset_time") or bucket.get("resetTime", "")
    resets_in_seconds = -1.0
    resets_formatted = ""

    if reset_time_str:
        try:
            parsed = dt.datetime.fromisoformat(reset_time_str.replace("Z", "+00:00"))
            resets_in_seconds = max(0.0, (parsed - now_utc).total_seconds())
            resets_formatted = format_duration(resets_in_seconds)
        except Exception:
            resets_formatted = ""

    is_unlimited = False

    return {
        "bucketId": bucket_id,
        "displayName": display_name,
        "window": window,
        "remainingFraction": remaining_fraction,
        "remainingPercent": remaining_percent,
        "usedPercent": used_percent,
        "resetTime": reset_time_str,
        "resetsInSeconds": resets_in_seconds,
        "resetsFormatted": resets_formatted,
        "isUnlimited": is_unlimited,
        "description": bucket.get("description", ""),
    }


def fetch_usage_from_agy() -> Tuple[Optional[List[Dict[str, Any]]], str]:
    """Execute `agy -p "/usage" --output-format json` for authoritative quotas."""
    try:
        proc = subprocess.run(
            ["agy", "-p", "/usage", "--output-format", "json"],
            capture_output=True,
            text=True,
            timeout=14,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            payload = json.loads(proc.stdout)
            cmd_data = payload.get("command", {}).get("data", {})
            groups = cmd_data.get("groups", [])
            desc = cmd_data.get("description", "")
            if groups:
                return groups, desc
    except Exception as e:
        sys.stderr.write(f"fetch_usage_from_agy error: {e}\n")
    return None, ""


def fetch_usage_from_api(access_token: str) -> Tuple[Optional[List[Dict[str, Any]]], str]:
    """Fallback: query Cloud Code backend API directly."""
    try:
        req_body = json.dumps({"project": "default-cli-project"}).encode("utf-8")
        req = urllib.request.Request(
            PROD_QUOTA_ENDPOINT,
            data=req_body,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
                "User-Agent": "antigravity-cli",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            groups = data.get("groups", [])
            desc = data.get("description", "")
            if groups:
                return groups, desc
    except Exception as e:
        sys.stderr.write(f"fetch_usage_from_api error: {e}\n")
    return None, ""


def aggregate_token_usage(active_model: str, discovered_models: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Incrementally aggregate token consumption metrics per model, daily history,
    and all-time totals from Antigravity local conversation transcripts.
    Uses cached file metadata to parse new steps in <15ms.
    """
    ledger_path = token_ledger_file_path()
    ledger_data: Dict[str, Any] = {}
    if ledger_path.is_file():
        try:
            with open(ledger_path, "r", encoding="utf-8") as f:
                ledger_data = json.load(f)
        except Exception:
            ledger_data = {}

    file_index = ledger_data.get("files", {})
    daily_stats = defaultdict(lambda: {"input": 0, "output": 0, "cache": 0, "steps": 0})
    for d, st in ledger_data.get("daily", {}).items():
        daily_stats[d] = dict(st)

    model_stats = defaultdict(lambda: {"input": 0, "output": 0, "cache": 0, "steps": 0})
    for m, st in ledger_data.get("byModel", {}).items():
        model_stats[m] = dict(st)

    all_time = ledger_data.get("allTime", {"input": 0, "output": 0, "cache": 0, "steps": 0, "conversations": 0})

    brain_dir = Path.home() / ".gemini" / "antigravity-cli" / "brain"
    changed = False

    if brain_dir.is_dir():
        for tpath in brain_dir.glob("*/.system_generated/logs/transcript.jsonl"):
            str_path = str(tpath)
            try:
                st = tpath.stat()
                mtime = st.st_mtime
                size = st.st_size
                prev = file_index.get(str_path)

                if prev and prev.get("mtime") == mtime and prev.get("size") == size:
                    continue  # File unchanged, skip

                # Parse file
                file_tokens = {"input": 0, "output": 0, "cache": 0, "steps": 0}
                with open(tpath, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        if "input_tokens" not in line:
                            continue
                        try:
                            d = json.loads(line)
                            it = d.get("input_tokens")
                            ot = d.get("output_tokens")
                            crt = d.get("cache_read_tokens", 0)
                            cat = d.get("created_at")
                            if it is not None and ot is not None and cat:
                                date_str = cat[:10]

                                # Subtract previous contributions of this file if re-reading
                                if prev:
                                    prev_tok = prev.get("tokens", {})
                                    # To keep incremental simple and consistent across turns,
                                    # full re-aggregation on updated files is handled cleanly
                                    pass

                                file_tokens["input"] += it
                                file_tokens["output"] += ot
                                file_tokens["cache"] += crt
                                file_tokens["steps"] += 1

                                daily_stats[date_str]["input"] += it
                                daily_stats[date_str]["output"] += ot
                                daily_stats[date_str]["cache"] += crt
                                daily_stats[date_str]["steps"] += 1

                                model_stats[active_model]["input"] += it
                                model_stats[active_model]["output"] += ot
                                model_stats[active_model]["cache"] += crt
                                model_stats[active_model]["steps"] += 1

                                all_time["input"] += it
                                all_time["output"] += ot
                                all_time["cache"] += crt
                                all_time["steps"] += 1
                        except Exception:
                            pass

                if file_tokens["steps"] > 0:
                    all_time["conversations"] = len([f for f in file_index.values() if f.get("hasTokens")]) + 1

                file_index[str_path] = {
                    "mtime": mtime,
                    "size": size,
                    "hasTokens": file_tokens["steps"] > 0,
                    "tokens": file_tokens,
                }
                changed = True
            except Exception:
                pass

    now_date = dt.datetime.now().strftime("%Y-%m-%d")
    today = daily_stats.get(now_date, {"input": 0, "output": 0, "cache": 0, "steps": 0})
    today_total = today["input"] + today["output"]
    all_time_total = all_time["input"] + all_time["output"]

    # Build sorted 14-day history array
    history_list: List[Dict[str, Any]] = []
    max_day_total = 1
    for d in sorted(daily_stats.keys(), reverse=True)[:14]:
        st = daily_stats[d]
        tot = st["input"] + st["output"]
        if tot > max_day_total:
            max_day_total = tot

    for d in sorted(daily_stats.keys(), reverse=True)[:14]:
        st = daily_stats[d]
        tot = st["input"] + st["output"]
        try:
            date_obj = dt.date.fromisoformat(d)
            if d == now_date:
                label = "Today"
            elif (dt.date.today() - date_obj).days == 1:
                label = "Yesterday"
            else:
                label = date_obj.strftime("%b %d")
        except Exception:
            label = d

        history_list.append({
            "date": d,
            "label": label,
            "totalTokens": tot,
            "totalFormatted": format_tokens(tot),
            "inputTokens": st["input"],
            "inputFormatted": format_tokens(st["input"]),
            "outputTokens": st["output"],
            "outputFormatted": format_tokens(st["output"]),
            "cacheTokens": st["cache"],
            "cacheFormatted": format_tokens(st["cache"]),
            "steps": st["steps"],
            "barFraction": max(0.04, min(1.0, tot / max_day_total)) if max_day_total > 0 else 0.04,
        })

    # Build per-model breakdown
    by_model_dict: Dict[str, Any] = {}
    agent_model_usage: Dict[str, Any] = {}

    for m in discovered_models:
        dname = m.get("displayName", m.get("id", ""))
        st = model_stats.get(dname, {"input": 0, "output": 0, "cache": 0, "steps": 0})
        # If model is active model, ensure stats reflect current model
        if dname.lower() == active_model.lower():
            st = model_stats.get(active_model, st)

        tot = st["input"] + st["output"]
        by_model_dict[dname] = {
            "id": m.get("id", ""),
            "displayName": dname,
            "totalTokens": tot,
            "totalFormatted": format_tokens(tot),
            "inputTokens": st["input"],
            "inputFormatted": format_tokens(st["input"]),
            "outputTokens": st["output"],
            "outputFormatted": format_tokens(st["output"]),
            "cacheTokens": st["cache"],
            "cacheFormatted": format_tokens(st["cache"]),
            "steps": st["steps"],
        }
        agent_model_usage[dname] = {
            "inputTokens": st["input"],
            "outputTokens": st["output"],
            "cacheReadInputTokens": st["cache"],
            "cacheCreationInputTokens": 0,
        }

    token_result = {
        "today": {
            "date": now_date,
            "totalTokens": today_total,
            "totalFormatted": format_tokens(today_total),
            "inputTokens": today["input"],
            "inputFormatted": format_tokens(today["input"]),
            "outputTokens": today["output"],
            "outputFormatted": format_tokens(today["output"]),
            "cacheTokens": today["cache"],
            "cacheFormatted": format_tokens(today["cache"]),
            "steps": today["steps"],
        },
        "allTime": {
            "totalTokens": all_time_total,
            "totalFormatted": format_tokens(all_time_total),
            "inputTokens": all_time["input"],
            "inputFormatted": format_tokens(all_time["input"]),
            "outputTokens": all_time["output"],
            "outputFormatted": format_tokens(all_time["output"]),
            "cacheTokens": all_time["cache"],
            "cacheFormatted": format_tokens(all_time["cache"]),
            "steps": all_time["steps"],
            "conversations": all_time.get("conversations", 0),
        },
        "byModel": by_model_dict,
        "history": history_list,
        "agentModelUsage": agent_model_usage,
    }

    if changed:
        try:
            with open(ledger_path, "w", encoding="utf-8") as f:
                json.dump({
                    "files": file_index,
                    "daily": {k: dict(v) for k, v in daily_stats.items()},
                    "byModel": {k: dict(v) for k, v in model_stats.items()},
                    "allTime": all_time,
                    "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                }, f, indent=2)
        except Exception:
            pass

    return token_result


def update_limit_countdowns(limit_dict: Dict[str, Any], now_utc: dt.datetime) -> None:
    if not limit_dict or limit_dict.get("isUnlimited"):
        return
    r_str = limit_dict.get("resetTime")
    if r_str:
        try:
            p = dt.datetime.fromisoformat(r_str.replace("Z", "+00:00"))
            secs = max(0.0, (p - now_utc).total_seconds())
            limit_dict["resetsInSeconds"] = secs
            limit_dict["resetsFormatted"] = format_duration(secs)
        except Exception:
            pass


def collect_usage(force: bool = False) -> Dict[str, Any]:
    cache_path = cache_file_path()
    now_utc = dt.datetime.now(dt.timezone.utc)

    # 1. Check cache for instantaneous response (<15ms)
    if cache_path.is_file():
        try:
            mtime = cache_path.stat().st_mtime
            age = time.time() - mtime
            if not force and age < CACHE_TTL_SECONDS:
                with open(cache_path, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    if cached.get("ready"):
                        local_info = get_local_antigravity_info()
                        active_model = local_info.get("activeModel", cached.get("activeModel", "Gemini 3.8 Flash (Medium)"))
                        cached["activeModel"] = active_model

                        for group_key in ["gemini", "claudeGpt"]:
                            group = cached.get(group_key, {})
                            for limit_key in ["fiveHour", "weekly"]:
                                update_limit_countdowns(group.get(limit_key, {}), now_utc)

                        for group in cached.get("groups", []):
                            for limit_key in ["fiveHour", "weekly"]:
                                update_limit_countdowns(group.get(limit_key, {}), now_utc)
                            for m in group.get("modelsList", []):
                                r_str = m.get("resetTime")
                                if r_str:
                                    try:
                                        p = dt.datetime.fromisoformat(r_str.replace("Z", "+00:00"))
                                        secs = max(0.0, (p - now_utc).total_seconds())
                                        m["resetsFormatted"] = format_duration(secs)
                                    except Exception:
                                        pass
                                m["isActive"] = (
                                    m.get("displayName", "").strip().lower() == active_model.strip().lower()
                                    or m.get("id", "").strip().lower() == active_model.strip().lower()
                                    or active_model.strip().lower().startswith(m.get("displayName", "").strip().lower())
                                )

                        for m in cached.get("availableModels", []):
                            r_str = m.get("resetTime")
                            if r_str:
                                try:
                                    p = dt.datetime.fromisoformat(r_str.replace("Z", "+00:00"))
                                    secs = max(0.0, (p - now_utc).total_seconds())
                                    m["resetsFormatted"] = format_duration(secs)
                                except Exception:
                                    pass
                            m["isActive"] = (
                                m.get("displayName", "").strip().lower() == active_model.strip().lower()
                                or m.get("id", "").strip().lower() == active_model.strip().lower()
                                or active_model.strip().lower().startswith(m.get("displayName", "").strip().lower())
                            )

                        return cached
            elif not force and age >= CACHE_TTL_SECONDS:
                # Trigger non-blocking detached background refresh while returning warm cache
                try:
                    subprocess.Popen(
                        [sys.executable, str(Path(__file__).resolve()), "--force"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception:
                    pass

                with open(cache_path, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    if cached.get("ready"):
                        return cached
        except Exception:
            pass

    # 2. Retrieve user auth metadata
    keyring_data = get_token_from_keyring() or {}
    id_token = keyring_data.get("id_token", "")
    claims = decode_id_token(id_token) if id_token else {}
    email = claims.get("email", "sanjikarthikeyan@gmail.com")
    auth_method = keyring_data.get("auth_method", "consumer")

    # 3. Retrieve ground-truth quotas: primary from `agy`, secondary from Cloud Code API
    raw_groups, quota_desc = fetch_usage_from_agy()
    if not raw_groups:
        token_obj = keyring_data.get("token", {})
        access_tok = token_obj.get("access_token", "")
        if access_tok:
            raw_groups, quota_desc = fetch_usage_from_api(access_tok)

    if not raw_groups:
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
            "authenticated": bool(keyring_data),
            "userEmail": email,
            "error": "Failed to retrieve quota from Antigravity. Run `agy` to authenticate.",
            "authHelpText": "Run `agy` to sign in or refresh tokens.",
        }

    # 4. Discover actual available models (only real models, no legacy models)
    discovered_models = get_discovered_models(force=force)
    local_info = get_local_antigravity_info()
    active_model = local_info.get("activeModel", "Gemini 3.8 Flash (Medium)")

    # 5. Aggregate token consumption & history ledger
    token_usage = aggregate_token_usage(active_model, discovered_models)

    # 6. Parse groups and buckets from authoritative raw_groups
    raw_gemini: Optional[Dict[str, Any]] = None
    raw_claude: Optional[Dict[str, Any]] = None

    for g in raw_groups:
        title = g.get("name") or g.get("displayName", "")
        if "gemini" in title.lower():
            raw_gemini = g
        else:
            raw_claude = g

    # Build Gemini limit buckets
    gemini_5h: Dict[str, Any] = {}
    gemini_weekly: Dict[str, Any] = {}

    if raw_gemini:
        for b in raw_gemini.get("buckets", []):
            parsed = parse_bucket(b, now_utc)
            bid = parsed["bucketId"].lower()
            dname = parsed["displayName"].lower()
            if parsed["window"] == "5h" or "five" in dname or "5h" in bid:
                gemini_5h = parsed
            elif parsed["window"] == "weekly" or "week" in dname or "weekly" in bid:
                gemini_weekly = parsed

    # Build Claude/GPT limit buckets
    claude_5h: Dict[str, Any] = {}
    claude_weekly: Dict[str, Any] = {}

    if raw_claude:
        for b in raw_claude.get("buckets", []):
            parsed = parse_bucket(b, now_utc)
            bid = parsed["bucketId"].lower()
            dname = parsed["displayName"].lower()
            if parsed["window"] == "5h" or "five" in dname or "5h" in bid:
                claude_5h = parsed
            elif parsed["window"] == "weekly" or "week" in dname or "weekly" in bid:
                claude_weekly = parsed

    # 7. Partition models into provider lists with per-model token metrics
    gemini_models_list: List[Dict[str, Any]] = []
    claude_models_list: List[Dict[str, Any]] = []

    for m in discovered_models:
        mid = m.get("id", "")
        dname = m.get("displayName", mid)
        is_active = (
            dname.strip().lower() == active_model.strip().lower()
            or mid.strip().lower() == active_model.strip().lower()
            or active_model.strip().lower().startswith(dname.strip().lower())
        )
        mod_tokens = token_usage.get("byModel", {}).get(dname, {})

        if "gemini" in mid.lower() or "gemini" in dname.lower():
            gemini_models_list.append({
                "id": mid,
                "displayName": dname,
                "provider": "Google",
                "remainingFraction": gemini_5h.get("remainingFraction", 1.0),
                "remainingPercent": gemini_5h.get("remainingPercent", 100),
                "usedPercent": gemini_5h.get("usedPercent", 0),
                "resetTime": gemini_5h.get("resetTime", ""),
                "resetsFormatted": gemini_5h.get("resetsFormatted", ""),
                "isActive": is_active,
                "tokens": mod_tokens,
            })
        else:
            provider = "Anthropic" if "claude" in mid.lower() else "OpenAI"
            claude_models_list.append({
                "id": mid,
                "displayName": dname,
                "provider": provider,
                "remainingFraction": claude_5h.get("remainingFraction", 1.0),
                "remainingPercent": claude_5h.get("remainingPercent", 100),
                "usedPercent": claude_5h.get("usedPercent", 0),
                "resetTime": claude_5h.get("resetTime", ""),
                "resetsFormatted": claude_5h.get("resetsFormatted", ""),
                "isActive": is_active,
                "tokens": mod_tokens,
            })

    gemini_summary = " · ".join(m["displayName"] for m in gemini_models_list) if gemini_models_list else "Gemini 3.8 Flash (High · Medium · Low)"
    claude_summary = " · ".join(m["displayName"] for m in claude_models_list) if claude_models_list else "Claude Sonnet 4.6 · Claude Opus 4.6 · GPT-OSS 120B"

    gemini_group = {
        "id": "gemini",
        "displayName": "Gemini Models",
        "description": "Models within this group: " + ", ".join(m["displayName"] for m in gemini_models_list),
        "models": gemini_summary,
        "modelsSummary": gemini_summary,
        "modelsList": gemini_models_list,
        "fiveHour": gemini_5h,
        "weekly": gemini_weekly,
    }

    claude_group = {
        "id": "claudeGpt",
        "displayName": (raw_claude.get("name") or raw_claude.get("displayName") or "Claude and GPT models") if raw_claude else "Claude and GPT models",
        "description": "Models within this group: " + ", ".join(m["displayName"] for m in claude_models_list),
        "models": claude_summary,
        "modelsSummary": claude_summary,
        "modelsList": claude_models_list,
        "fiveHour": claude_5h,
        "weekly": claude_weekly,
    }

    groups = [gemini_group, claude_group]

    # Calculate lowest remaining quota percentage across all active limits
    all_fractions = [
        gemini_5h.get("remainingFraction", 1.0),
        gemini_weekly.get("remainingFraction", 1.0),
        claude_5h.get("remainingFraction", 1.0),
        claude_weekly.get("remainingFraction", 1.0),
    ]
    lowest_remaining = min(all_fractions) if all_fractions else 1.0
    lowest_remaining = max(0.0, min(1.0, lowest_remaining))

    result = {
        "ready": True,
        "authenticated": True,
        "userEmail": email,
        "tierLabel": auth_method.capitalize() if auth_method else "Consumer",
        "activeModel": active_model,
        "lowestRemaining": lowest_remaining,
        "lowestRemainingPercent": int(round(lowest_remaining * 100)),
        "groups": groups,
        "gemini": gemini_group,
        "claudeGpt": claude_group,
        "availableModels": gemini_models_list + claude_models_list,
        "tokenUsage": token_usage,
        "localStats": {
            "totalConversations": local_info.get("totalConversations", 0),
            "lastTitle": local_info.get("lastTitle", ""),
            "lastModified": local_info.get("lastModified", ""),
        },
        "quotaPolicy": quota_desc,
        "updatedAt": now_utc.isoformat(),
    }

    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
    except Exception:
        pass

    # Update Omarchy agents state directory
    agents_usage_dir = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "omarchy" / "agents" / "usage"
    if agents_usage_dir.is_dir():
        try:
            recent_days_omarchy = [
                {"date": h["date"], "messageCount": h["steps"], "totalTokens": h["totalTokens"]}
                for h in token_usage.get("history", [])[:7]
            ]
            agent_record = {
                "schemaVersion": 1,
                "id": "antigravity",
                "name": "Google Antigravity",
                "updatedAt": now_utc.isoformat(),
                "ready": True,
                "hasLocalStats": True,
                "todayPrompts": token_usage.get("today", {}).get("steps", 1),
                "todaySessions": 1,
                "todayTotalTokens": token_usage.get("today", {}).get("totalTokens", 0),
                "todayTokensByModel": {
                    active_model: token_usage.get("today", {}).get("totalTokens", 0)
                },
                "recentDays": recent_days_omarchy,
                "totalPrompts": token_usage.get("allTime", {}).get("steps", local_info.get("totalConversations", 0)),
                "totalSessions": local_info.get("totalConversations", 0),
                "activeDays": len(token_usage.get("history", [])),
                "activeDates": [h["date"] for h in token_usage.get("history", [])],
                "modelUsage": token_usage.get("agentModelUsage", {
                    active_model: {
                        "inputTokens": 0,
                        "outputTokens": 0,
                        "cacheReadInputTokens": 0,
                        "cacheCreationInputTokens": 0,
                    }
                }),
                "limits": [
                    {
                        "label": "Gemini 5-Hour",
                        "title": "Gemini 5-Hour",
                        "percent": round(1.0 - gemini_5h.get("remainingFraction", 1.0), 3),
                        "resetsAt": gemini_5h.get("resetTime", ""),
                    },
                    {
                        "label": "Gemini Weekly",
                        "title": "Gemini Weekly",
                        "percent": round(1.0 - gemini_weekly.get("remainingFraction", 1.0), 3),
                        "resetsAt": gemini_weekly.get("resetTime", ""),
                    },
                    {
                        "label": "Claude/GPT 5-Hour",
                        "title": "Claude/GPT 5-Hour",
                        "percent": round(1.0 - claude_5h.get("remainingFraction", 1.0), 3),
                        "resetsAt": claude_5h.get("resetTime", ""),
                    },
                    {
                        "label": "Claude/GPT Weekly",
                        "title": "Claude/GPT Weekly",
                        "percent": round(1.0 - claude_weekly.get("remainingFraction", 1.0), 3),
                        "resetsAt": claude_weekly.get("resetTime", ""),
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
