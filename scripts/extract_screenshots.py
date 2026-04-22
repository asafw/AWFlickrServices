#!/usr/bin/env python3
"""Extract named XCTAttachment PNGs from an xcresult bundle into an output directory.

Usage: python3 extract_screenshots.py <bundle.xcresult> <out_dir>
"""

import json, subprocess, os, shutil, sys

BUNDLE = sys.argv[1]
OUT    = sys.argv[2]

def xcresult_get(ref_id=None):
    cmd = ['xcrun', 'xcresulttool', 'get', '--legacy',
           '--path', BUNDLE, '--format', 'json']
    if ref_id:
        cmd += ['--id', ref_id]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(r.stdout)

def walk(node, type_name, results):
    if isinstance(node, dict):
        if node.get('_type', {}).get('_name') == type_name:
            results.append(node)
        for v in node.values():
            walk(v, type_name, results)
    elif isinstance(node, list):
        for v in node:
            walk(v, type_name, results)

top         = xcresult_get()
tests_ref   = top['actions']['_values'][0]['actionResult']['testsRef']['id']['_value']
summaries   = xcresult_get(tests_ref)

metas = []
walk(summaries, 'ActionTestMetadata', metas)

os.makedirs(OUT, exist_ok=True)
copied = 0

for meta in metas:
    summary_ref = meta.get('summaryRef', {}).get('id', {}).get('_value', '')
    if not summary_ref:
        continue
    test_summary  = xcresult_get(summary_ref)
    attachments   = []
    walk(test_summary, 'ActionTestAttachment', attachments)
    for att in attachments:
        name = att.get('name', {}).get('_value', '')
        ref  = att.get('payloadRef', {}).get('id', {}).get('_value', '')
        if not (name and ref):
            continue
        # Try standard xcresult Data layout first, then the flat Attachments folder.
        src = os.path.join(BUNDLE, 'Data', f'data.{ref}')
        if not os.path.exists(src):
            src = os.path.join(BUNDLE, 'Attachments', ref)
        if not os.path.exists(src):
            continue
        # Skip XCTest-internal attachments.
        if name.startswith('kXCTAttachment') or name.startswith('App UI hierarchy'):
            continue
        fname = name if name.endswith('.png') else name + '.png'
        shutil.copy2(src, os.path.join(OUT, fname))
        print(f'  ✓ {fname}')
        copied += 1

print(f'Extracted {copied} screenshot(s) → {OUT}')
