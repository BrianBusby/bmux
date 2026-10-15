#!/usr/bin/env python3
"""Synthetic AppHang report contracts; archived Sentry payloads stay private."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_ci_app_host_failure_evidence import FakeTools, evidence

PREFIX = '[Sentry] [debug] [owned-time] [SentryEvent:82] Serialized event: '
UUID = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'


def event(image, *, uuid=UUID, base=0x1000, frame_count=2, image_count=1,
          mechanism='AppHang', value='SECRET payload', extra=''):
    """Build only the observed NSDictionary shape, using invented owned values."""
    frames = [{'instruction_addr': hex(base + 5 + index), 'image_addr': hex(base),
               'package': str(image)} for index in range(frame_count)]
    images = [{'code_file': str(image), 'debug_id': uuid, 'image_addr': hex(base + index * 0x1000),
               'image_size': 1024} for index in range(image_count)]
    decoded = {'debug_meta': {'images': images}, 'exception': {'values': [{
        'mechanism': {'type': mechanism}, 'type': 'Application Hang', 'value': value,
        'stacktrace': {'frames': frames}}]},
        'threads': {'values': [{'stacktrace': {'frames': [{'instruction_addr': hex(base + 999)}]}}]}}
    # Literal quoted newlines/braces exercise framing, not just JSON escapes.
    quoted_value = json.dumps(value).replace('\\n', '\n')
    image_rows = '\n'.join('        { code_file = %s; debug_id = %s; image_addr = "%s"; image_size = 1024; },'
                           % (json.dumps(str(image)), json.dumps(uuid), image_record['image_addr']) for image_record in images)
    frame_rows = '\n'.join('                { instruction_addr = "%s"; image_addr = "%s"; package = %s; },'
                           % (f['instruction_addr'], f['image_addr'], json.dumps(str(image))) for f in frames)
    body = ('{\n    debug_meta = { images = (\n' + image_rows + '\n    ); };\n'
            '    exception = { values = ({\n        mechanism = { type = ' + mechanism + '; };\n'
            '        type = "Application Hang";\n        value = ' + quoted_value + ';\n'
            '        stacktrace = { frames = (\n' + frame_rows + '\n        ); };\n    }); };\n'
            '    threads = { values = ({ stacktrace = { frames = ({ instruction_addr = "'
            + hex(base + 999) + '"; }); }; }); };\n' + extra + '}')
    return body, decoded


class HangTools(FakeTools):
    """Linux injects conversion only; UUID and symbol gates remain real collector code."""
    def __init__(self, responses, *, native=False, expire_symbols=False, expire_conversion=False):
        super().__init__()
        self.responses = responses
        self.native = native
        self.expire_symbols = expire_symbols
        self.expire_conversion = expire_conversion
        self.expired = False

    def remaining(self):
        if self.expired:
            raise TimeoutError('diagnostic_budget')
        return 30

    def run(self, args):
        if Path(args[0]).name == 'plutil':
            self.calls.append(args)
            if self.expire_conversion:
                self.expired = True
                raise TimeoutError('diagnostic_budget')
            body = Path(args[-1]).read_text().strip()
            if body not in self.responses:
                raise ValueError('unrecognized_owned_envelope')
            if self.native:
                return evidence.DiagnosticTools().run(args)
            return json.dumps(self.responses[body])
        if self.expire_symbols:
            self.expired = True
            self.calls.append(args)
            raise TimeoutError('diagnostic_budget')
        return super().run(args)


class SentryHangEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bmux-sentry-evidence-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'dd'
        self.products = self.root / 'Build/Products'
        self.image = self.products / 'owned.app/Contents/MacOS/owned'
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b'owned fixture image')
        self.log = Path(self.temp.name) / 'native.log'
        self.pending = Path(self.temp.name) / 'pending'

    def collect(self, bodies, tools):
        output = self.pending / 'attempt-1-ABC001/capture'
        self.log.write_text('\n'.join(PREFIX + body for body in bodies) + '\n')
        evidence.snapshot(self.root, output)
        evidence.defer_collection(self.root, self.log, output, 65)
        evidence.collect_pending(self.pending, tools)
        report = json.loads((output / 'report.json').read_text())
        self.assertEqual(report['native_exit_code'], 65)
        self.assertFalse((output / 'state.json').exists())
        self.assertFalse((output / 'native.log').exists())
        # Every converter input is private and gone after collection.
        for args in tools.calls:
            if Path(args[0]).name == 'plutil':
                self.assertFalse(Path(args[-1]).exists())
        return report

    def test_distinct_events_keep_exception_frame_order_and_private_fields_out(self):
        first, a = event(self.image)
        second, b = event(self.image, uuid='BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB', base=0x3000)
        tools = HangTools({first: a, second: b})
        report = self.collect([first, second], tools)
        hangs = report.get('hangs', [])
        self.assertEqual(len(hangs), 2)
        self.assertEqual(report['crashes'], [])
        for index, hang in enumerate(hangs):
            self.assertEqual(hang['stack_source'], 'exception')
            image = hang['images'][0]
            self.assertEqual(image['uuid'], ('a' if index == 0 else 'b') * 32)
            self.assertEqual(image['base'], '0x1000' if index == 0 else '0x3000')
            self.assertEqual([f['offset'] for f in image['frames']], ['0x5', '0x6'])
            self.assertEqual([f['frame_index'] for f in image['frames']], [0, 1])
            self.assertTrue(all(f['thread'] is None for f in image['frames']))
        encoded = json.dumps(report)
        for forbidden in ('SECRET', str(self.root), 'package', 'code_file', 'Application Hang'):
            self.assertNotIn(forbidden, encoded)

    @unittest.skipUnless(sys.platform == 'darwin', 'native OpenStep conversion requires macOS plutil')
    def test_actual_native_plutil_parses_synthetic_dictionary_and_quoted_delimiters(self):
        body, decoded = event(self.image, value='SECRET }\n' + PREFIX + '{ quoted \\" marker')
        report = self.collect([body], HangTools({body: decoded}, native=True))
        self.assertEqual(len(report.get('hangs', [])), 1)
        self.assertEqual(report['hangs'][0]['images'][0]['frames'][0]['offset'], '0x5')
        self.assertNotIn('SECRET', json.dumps(report))

    def test_nonhang_and_quoted_fake_envelope_do_not_borrow_following_images(self):
        ignored, ignored_value = event(self.image, mechanism='Other')
        quoted, quoted_value = event(self.image, value='SECRET }\n' + PREFIX + '{\n} still quoted')
        following, following_value = event(self.image, base=0x7000)
        tools = HangTools({ignored: ignored_value, quoted: quoted_value, following: following_value})
        report = self.collect([ignored, quoted, following], tools)
        hangs = report.get('hangs', [])
        self.assertEqual(len(hangs), 2)
        self.assertEqual([h['images'][0]['base'] for h in hangs], ['0x1000', '0x7000'])
        self.assertNotIn('SECRET', json.dumps(report))

    def test_incomplete_malformed_and_oversized_envelopes_fail_closed(self):
        body, decoded = event(self.image)
        # Many bounded lines exceed the envelope cap without relying on a giant line.
        oversized = body[:-1] + ('    unused = "' + 'x' * 1024 + '";\n') * 1024 + '}'
        tools = HangTools({body: decoded})
        report = self.collect([body[:-1], '{ invalid; }', oversized, body], tools)
        self.assertEqual(len(report.get('hangs', [])), 1)
        self.assertGreaterEqual(report.get('hang_limits', {}).get('envelopes_rejected', 0), 3)
        self.assertEqual(report['hangs'][0]['images'][0]['uuid'], 'a' * 32)

    def test_event_cap_reports_omitted_envelopes(self):
        body, decoded = event(self.image)
        report = self.collect([body] * 17, HangTools({body: decoded}))
        self.assertEqual(len(report.get('hangs', [])), 16)
        self.assertGreater(report.get('hang_limits', {}).get('events_omitted', 0), 0)

    def test_image_cap_uses_distinct_nonoverlapping_ranges(self):
        body, decoded = event(self.image, image_count=129)
        report = self.collect([body], HangTools({body: decoded}))
        hangs = report.get('hangs', [])
        self.assertEqual(len(hangs), 1)
        self.assertEqual(len(hangs[0]['images']), 128)
        self.assertEqual(sum(len(image['frames']) for image in hangs[0]['images']), 2)
        self.assertGreater(report.get('hang_limits', {}).get('images_omitted', 0), 0)

    def test_frame_cap_reports_omitted_exception_frames(self):
        body, decoded = event(self.image, frame_count=129)
        report = self.collect([body], HangTools({body: decoded}))
        hangs = report.get('hangs', [])
        self.assertEqual(len(hangs), 1)
        self.assertEqual(len(hangs[0]['images'][0]['frames']), 128)
        self.assertGreater(report.get('hang_limits', {}).get('frames_omitted', 0), 0)

    def test_outside_symlink_and_uuid_mismatch_never_reach_atos(self):
        outside = Path(self.temp.name) / 'outside'
        outside.write_bytes(b'owned outside fixture')
        link = self.products / 'escape'
        link.symlink_to(outside)
        variants = [event(outside), event(link), event(self.image, uuid='BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB')]
        tools = HangTools(dict(variants))
        report = self.collect([body for body, _ in variants], tools)
        hangs = report.get('hangs', [])
        self.assertEqual(len(hangs), 3)
        self.assertEqual([h['images'][0]['symbolication'] for h in hangs],
                         ['outside_products_or_missing', 'outside_products_or_missing', 'uuid_mismatch'])
        self.assertFalse(any('atos' in args for args in tools.calls))

    def test_all_attempt_conversions_precede_exhausted_symbol_budget(self):
        bodies = [event(self.image, base=base) for base in (0x1000, 0x3000)]
        tools = HangTools(dict(bodies), expire_symbols=True)
        outputs = []
        for index, (body, _) in enumerate(bodies):
            output = self.pending / f'attempt-1-ABC00{index}/capture'
            outputs.append(output)
            self.log.write_text(PREFIX + body + '\n')
            evidence.snapshot(self.root, output)
            evidence.defer_collection(self.root, self.log, output, 65)
        evidence.collect_pending(self.pending, tools)
        for output in outputs:
            report = json.loads((output / 'report.json').read_text())
            self.assertEqual(len(report.get('hangs', [])), 1)
            image = report['hangs'][0]['images'][0]
            self.assertEqual(image['symbolication'], 'TimeoutError')
            self.assertEqual(image['frames'][0]['offset'], '0x5')
            self.assertFalse((output / 'native.log').exists())
        self.assertEqual([Path(args[0]).name for args in tools.calls[:2]], ['plutil', 'plutil'])

    def test_conversion_budget_cannot_erase_later_attempt_native_records(self):
        body, decoded = event(self.image)
        tools = HangTools({body: decoded}, expire_conversion=True)
        outputs = []
        for index, text in enumerate((PREFIX + body, '\n'.join([
                'Program crashed: owned synthetic crash', 'Thread 0 crashed:',
                '0 0x1005 owned',
                f'0x1000–0x1400 {"a" * 32} owned  {self.image}',
                'Restarting after unexpected exit, crash, or test timeout']))):
            output = self.pending / f'attempt-1-ABC00{index}/capture'
            outputs.append(output)
            self.log.write_text(text + '\n')
            evidence.snapshot(self.root, output)
            evidence.defer_collection(self.root, self.log, output, 65)
        evidence.collect_pending(self.pending, tools)
        first, later = [json.loads((output / 'report.json').read_text()) for output in outputs]
        self.assertGreater(first.get('hang_limits', {}).get('conversion_budget_omitted', 0), 0)
        self.assertEqual(len(later['crashes']), 1)
        self.assertEqual(later['crashes'][0]['images'][0]['frames'][0]['offset'], '0x5')
        self.assertEqual(later['events'][0]['kind'], 'runner_restart')
        self.assertFalse(later['log_limits']['budget_expired'])
        self.assertTrue(all(not (output / 'native.log').exists() for output in outputs))

    def test_converter_budget_and_final_report_caps_are_visible(self):
        body, decoded = event(self.image)
        tools = HangTools({body: decoded}, expire_conversion=True)
        report = self.collect([body, body], tools)
        self.assertEqual(report.get('hangs', []), [])
        self.assertGreaterEqual(report.get('hang_limits', {}).get('conversion_budget_omitted', 0), 1)
        # A separate attempt proves hangs share the existing final byte cap.
        self.pending = Path(self.temp.name) / 'report-cap'
        with patch.object(evidence, 'MAX_REPORT_BYTES', 256):
            limited = self.collect([body], HangTools({body: decoded}))
        self.assertIn('report_byte_limit', limited['errors'])
        self.assertEqual(limited.get('hangs', []), [])


if __name__ == '__main__':
    unittest.main()
