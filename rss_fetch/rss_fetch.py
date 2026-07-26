#!/usr/bin/env python3
import os
import json
import urllib.request
import xml.etree.ElementTree as ET

def fetch_rss():
    try:
        params_json = os.environ.get('AGENTA_TOOL_PARAMS', '{}')
        params = json.loads(params_json)
        url = params.get('url')
        limit = params.get('limit', 5)

        if not url:
            return json.dumps({"error": "Missing url parameter"})

        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'})
        with urllib.request.urlopen(req) as response:
            content = response.read()

        root = ET.fromstring(content)
        items = []

        # RSS 2.0
        channel = root.find('.//channel')
        if channel is not None:
            for item in channel.findall('item')[:limit]:
                items.append({
                    'title': item.findtext('title'),
                    'link': item.findtext('link'),
                    'published': item.findtext('pubDate')
                })
        
        # Atom
        if not items:
            ns = {'atom': 'http://www.w3.org/2005/Atom'}
            for entry in root.findall('.//atom:entry', ns)[:limit]:
                link = entry.find('atom:link', ns)
                items.append({
                    'title': entry.findtext('atom:title', namespaces=ns),
                    'link': link.get('href') if link is not None else None,
                    'published': entry.findtext('atom:published', namespaces=ns) or entry.findtext('atom:updated', namespaces=ns)
                })

        return json.dumps(items)
    except Exception as e:
        return json.dumps([{"error": str(e)}])

if __name__ == '__main__':
    print(fetch_rss())