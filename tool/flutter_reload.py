#!/usr/bin/env python3
import asyncio
import json
import os
import re
import sys
import subprocess
import urllib.parse
import urllib.request

def make_frame(payload_str):
    data = payload_str.encode('utf-8')
    length = len(data)
    mask = os.urandom(4)
    if length < 126:
        header = bytes([0x81, 0x80 | length]) + mask
    elif length < 65536:
        header = bytes([0x81, 0x80 | 126]) + length.to_bytes(2, 'big') + mask
    else:
        header = bytes([0x81, 0x80 | 127]) + length.to_bytes(8, 'big') + mask
    masked = bytes([b ^ mask[i % 4] for i, b in enumerate(data)])
    return header + masked

async def get_frame(reader):
    head = await reader.readexactly(2)
    b1 = head[1]
    masked = bool(b1 & 0x80)
    length = b1 & 0x7f
    if length == 126:
        length = int.from_bytes(await reader.readexactly(2), 'big')
    elif length == 127:
        length = int.from_bytes(await reader.readexactly(8), 'big')
    mask = await reader.readexactly(4) if masked else b''
    data = await reader.readexactly(length)
    if masked:
        data = bytes([b ^ mask[i % 4] for i, b in enumerate(data)])
    return data.decode('utf-8', errors='ignore')

def get_ws_url():
    try:
        out = subprocess.check_output(['ps', 'aux']).decode('utf-8')
        m = re.search(r'--vm-service-uri=(http://127\.0\.0\.1:\d+/[^/]+/)', out)
        if not m:
            return None
        url = m.group(1)
        resp = urllib.request.urlopen(url)
        final_url = resp.geturl()
        parsed = urllib.parse.urlparse(final_url)
        params = urllib.parse.parse_qs(parsed.query)
        if 'uri' in params:
            return params['uri'][0]
        # fallback
        return f"ws://{parsed.netloc}{parsed.path}ws"
    except Exception as e:
        print('Error resolving ws url:', e)
        return None

async def trigger(mode='reload'):
    ws_url = get_ws_url()
    if not ws_url:
        print('No running Flutter VM service found.')
        return False

    parsed = urllib.parse.urlparse(ws_url)
    host = parsed.hostname or '127.0.0.1'
    port = parsed.port
    path = parsed.path

    reader, writer = await asyncio.open_connection(host, port)
    req = (
        f'GET {path} HTTP/1.1\r\n'
        f'Host: {host}:{port}\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
        'Sec-WebSocket-Version: 13\r\n\r\n'
    )
    writer.write(req.encode('utf-8'))
    await writer.drain()
    
    line = await reader.readline()
    while line.strip():
        line = await reader.readline()
    
    # Listen to services
    writer.write(make_frame(json.dumps({'jsonrpc': '2.0', 'id': 'listen_srv', 'method': 'streamListen', 'params': {'streamId': 'Service'}})))
    await writer.drain()
    
    service_map = {}
    while True:
        frame = await get_frame(reader)
        data = json.loads(frame)
        if data.get('method') == 'streamNotify':
            ev = data.get('params', {}).get('event', {})
            if ev.get('kind') == 'ServiceRegistered':
                service_map[ev['service']] = ev['method']
        if data.get('id') == 'listen_srv':
            break

    if mode == 'restart':
        method = service_map.get('hotRestart', 's1.hotRestart')
        writer.write(make_frame(json.dumps({
            'jsonrpc': '2.0',
            'id': 'restart_req',
            'method': method,
            'params': {}
        })))
        await writer.drain()
        while True:
            frame = await get_frame(reader)
            data = json.loads(frame)
            if data.get('id') == 'restart_req':
                print(f'Hot restart result: {frame}')
                break
    else:
        writer.write(make_frame(json.dumps({'jsonrpc': '2.0', 'id': 'get_vm', 'method': 'getVM'})))
        await writer.drain()
        vm_resp = None
        while True:
            frame = await get_frame(reader)
            data = json.loads(frame)
            if data.get('id') == 'get_vm':
                vm_resp = data
                break
        
        isolates = vm_resp.get('result', {}).get('isolates', [])
        main_isolate = next((iso for iso in isolates if iso.get('name') == 'main'), isolates[0] if isolates else None)
        if not main_isolate:
            print('Main isolate not found')
            return False
        
        method = service_map.get('reloadSources', 's1.reloadSources')
        writer.write(make_frame(json.dumps({
            'jsonrpc': '2.0',
            'id': 'reload_req',
            'method': method,
            'params': {'isolateId': main_isolate['id']}
        })))
        await writer.drain()
        while True:
            frame = await get_frame(reader)
            data = json.loads(frame)
            if data.get('id') == 'reload_req':
                print(f'Hot reload result: {frame}')
                break
    
    writer.close()
    await writer.wait_closed()
    return True

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'reload'
    asyncio.run(trigger(mode))
