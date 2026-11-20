#!/usr/bin/env python3
"""Prepare missing bundled verb glosses in development; never runs in the iOS app."""
from pathlib import Path
import argparse
import json
import sys
import urllib.error
import urllib.request

LANGUAGES = {"de": "German", "nl": "Dutch", "ru": "Russian"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", nargs="+", choices=LANGUAGES, default=list(LANGUAGES))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    path = root / "VoiceToRead/Resources/VerbReference/verbs.json"
    verbs = json.loads(path.read_text(encoding="utf-8"))
    key = None
    for locale in args.locales:
        missing = [verb for verb in verbs if locale not in verb["translations"]]
        if not missing:
            print(locale + ": existing glosses retained.", flush=True)
            continue
        if key is None:
            env = (root / ".env").read_text(encoding="utf-8-sig")
            key = next((line.partition("=")[2].strip().strip(chr(34)).strip(chr(39))
                        for line in env.splitlines()
                        if line.partition("=")[0].strip() == "OPENAI_API_KEY"), None)
            if not key:
                sys.exit("Missing local development key.")
        for offset in range(0, len(missing), 15):
            batch = missing[offset:offset + 15]
            strings = {verb["base"] + "|" + field: value for verb in batch
                       for field, value in verb["translations"]["en"].items()}
            senses = [{field: verb[field] for field in ("base", "meaningEn", "meaningEs", "complement")}
                      for verb in batch]
            schema = {"type": "object", "properties": {field: {"type": "string"} for field in strings},
                      "required": list(strings), "additionalProperties": False}
            payload = {"model": "gpt-4.1", "input": [
                {"role": "system", "content": "Translate educational English-verb glosses into " + LANGUAGES[locale] +
                 ". Preserve each sense and distinguish tense/form where natural. Return concise natural learner-facing equivalents, not explanations or English placeholders. All forms must match the contextual sense, e.g. grow vegetables means cultivate. Keep all keys. Editorial review is required before publishing generated content. For be, preserve both existence and state meanings. Context: " + json.dumps(senses, ensure_ascii=False)},
                {"role": "user", "content": json.dumps(strings, ensure_ascii=False)}],
                "text": {"format": {"type": "json_schema", "name": "verb_glosses", "strict": True, "schema": schema}}}
            request = urllib.request.Request("https://api.openai.com/v1/responses",
                data=json.dumps(payload, ensure_ascii=False).encode(),
                headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"}, method="POST")
            try:
                with urllib.request.urlopen(request, timeout=180) as response:
                    result = json.load(response)
            except urllib.error.HTTPError as error:
                sys.exit("OpenAI HTTP " + str(error.code) + " (credentials not logged).")
            except (urllib.error.URLError, TimeoutError):
                sys.exit("The content request failed; existing glosses retained.")
            text = "".join(content.get("text", "") for item in result.get("output", [])
                           for content in item.get("content", []) if content.get("type") == "output_text")
            translated = json.loads(text)
            if set(translated) != set(strings) or not all(isinstance(value, str) and value.strip() for value in translated.values()):
                sys.exit("Incomplete verb gloss response; existing glosses retained.")
            for verb in batch:
                verb["translations"][locale] = {field: translated[verb["base"] + "|" + field].strip()
                                                 for field in verb["translations"]["en"]}
            temporary = path.with_suffix(".json.tmp")
            temporary.write_text(json.dumps(verbs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            temporary.replace(path)
            print(locale + ": " + str(min(offset + 15, len(missing))) + "/" + str(len(missing)) + " missing verb glosses prepared.", flush=True)


if __name__ == "__main__":
    main()
