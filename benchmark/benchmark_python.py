#!/usr/bin/env python3
"""Performance benchmarks for Python SoCo library.

This script measures the performance of key operations:
- DIDL parsing (from_didl_string)
- XML parsing and serialization
- DIDL object creation and conversion

Run with: python3 benchmark/benchmark_python.py
"""

import sys
import os
import time

# Add SoCo to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'SoCo'))

from soco.data_structures_entry import from_didl_string
from soco.data_structures import (
    DidlMusicTrack,
    DidlResource,
    to_didl_string,
)

# Sample DIDL strings for benchmarking
SIMPLE_DIDL = '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" 
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" 
           xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" 
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="1" parentID="0" restricted="true">
    <dc:title>Test Track</dc:title>
    <upnp:class>object.item.audioItem.musicTrack</upnp:class>
    <res protocolInfo="http-get:*:audio/mpeg:*">http://example.com/track.mp3</res>
  </item>
</DIDL-Lite>'''

COMPLEX_DIDL = '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" 
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" 
           xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" 
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="1" parentID="0" restricted="true">
    <dc:title>Test Track</dc:title>
    <dc:creator>Test Artist</dc:creator>
    <upnp:class>object.item.audioItem.musicTrack</upnp:class>
    <upnp:artist>Test Artist</upnp:artist>
    <upnp:album>Test Album</upnp:album>
    <upnp:originalTrackNumber>1</upnp:originalTrackNumber>
    <res protocolInfo="http-get:*:audio/mpeg:*">http://example.com/track.mp3</res>
  </item>
  <container id="2" parentID="0" restricted="true">
    <dc:title>Test Album</dc:title>
    <upnp:class>object.container.album.musicAlbum</upnp:class>
    <upnp:artist>Test Artist</upnp:artist>
  </container>
</DIDL-Lite>'''


def benchmark(name, operation, iterations=1000, warmup_iterations=100):
    """Run a benchmark and print results."""
    # Warmup
    for _ in range(warmup_iterations):
        operation()
    
    # Actual benchmark
    start_time = time.perf_counter()
    for _ in range(iterations):
        operation()
    end_time = time.perf_counter()
    
    total_ms = (end_time - start_time) * 1000
    avg_ms = total_ms / iterations
    ops_per_sec = int(iterations / (end_time - start_time))
    
    print(f'{name}:')
    print(f'  Total: {total_ms:.2f}ms')
    print(f'  Average: {avg_ms:.3f}ms per operation')
    print(f'  Throughput: {ops_per_sec} ops/sec')


def main():
    print('Python SoCo Performance Benchmarks\n')
    print('=' * 50)
    
    # Benchmark 1: Simple DIDL parsing
    print('\n1. Simple DIDL Parsing (from_didl_string)')
    print('-' * 50)
    benchmark(
        'Parse simple DIDL (1000 iterations)',
        lambda: from_didl_string(SIMPLE_DIDL),
        iterations=1000,
    )
    
    # Benchmark 2: Complex DIDL parsing
    print('\n2. Complex DIDL Parsing')
    print('-' * 50)
    benchmark(
        'Parse complex DIDL (1000 iterations)',
        lambda: from_didl_string(COMPLEX_DIDL),
        iterations=1000,
    )
    
    # Benchmark 3: DIDL object creation
    print('\n3. DIDL Object Creation')
    print('-' * 50)
    benchmark(
        'Create DidlMusicTrack (10000 iterations)',
        lambda: DidlMusicTrack(
            title='Test Track',
            parent_id='0',
            item_id='1',
            restricted=True,
            resources=[
                DidlResource(
                    uri='http://example.com/track.mp3',
                    protocol_info='http-get:*:audio/mpeg:*',
                ),
            ],
            artist='Test Artist',
            album='Test Album',
        ),
        iterations=10000,
    )
    
    # Benchmark 4: DIDL to string conversion
    print('\n4. DIDL to String Conversion (to_didl_string)')
    print('-' * 50)
    parsed_objects = from_didl_string(COMPLEX_DIDL)
    benchmark(
        'Convert DIDL objects to string (1000 iterations)',
        lambda: to_didl_string(*parsed_objects),
        iterations=1000,
    )
    
    # Benchmark 5: Round-trip (parse -> create -> serialize)
    print('\n5. Round-trip Performance')
    print('-' * 50)
    benchmark(
        'Parse -> Serialize round-trip (500 iterations)',
        lambda: to_didl_string(*from_didl_string(COMPLEX_DIDL)),
        iterations=500,
    )
    
    # Benchmark 6: from_element performance
    print('\n6. from_element Performance')
    print('-' * 50)
    import lxml.etree as ET
    parsed = from_didl_string(SIMPLE_DIDL)
    if parsed:
        # Get the XML element from the parsed object
        doc = ET.fromstring(SIMPLE_DIDL.encode('utf-8'))
        element = doc[0]  # First child element
        benchmark(
            'Create DidlObject from XML element (5000 iterations)',
            lambda: DidlMusicTrack.from_element(element),
            iterations=5000,
        )
    
    print('\n' + '=' * 50)
    print('Benchmarks completed!')


if __name__ == '__main__':
    main()

