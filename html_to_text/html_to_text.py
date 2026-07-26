#!/usr/bin/env python3
import json
import os
import sys
import urllib.request
from html.parser import HTMLParser

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
        self.ignore = False

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self.ignore = True

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.ignore = False

    def handle_data(self, data):
        if not self.ignore:
            self.text.append(data)

def main():
    try:
        params_json = os.environ.get('AGENTA_TOOL_PARAMS', '{}')
        params = json.loads(params_json)
        url = params.get('url')
        max_chars = params.get('max_chars', 5000)

        if not url:
            print(json.dumps({"error": "Missing required parameter: url"}))
            sys.exit(1)

        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'})
        with urllib.request.urlopen(req) as response:
            html_content = response.read().decode('utf-8', errors='ignore')

        parser = TextExtractor()
        parser.feed(html_content)
        full_text = ' '.join(parser.text)
        collapsed_text = ' '.join(full_text.split())
        
        result = collapsed_text[:max_chars]
        print(json.dumps({"result": result}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    main()