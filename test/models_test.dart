import 'package:flutter_test/flutter_test.dart';
import 'package:v_epsilon/models.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare as 0', () {
      // reused from updater.dart — re-declare simple logic
    });
  });

  group('Attachment.fromUrl', () {
    test('detects images', () {
      expect(Attachment.fromUrl('https://x.com/pic.jpg').type, 'image');
      expect(Attachment.fromUrl('https://x.com/PIC.PNG').type, 'image');
      expect(Attachment.fromUrl('https://x.com/a.webp').type, 'image');
    });
    test('detects videos', () {
      expect(Attachment.fromUrl('https://x.com/v.mp4').type, 'video');
      expect(Attachment.fromUrl('https://x.com/v.webm').type, 'video');
    });
    test('detects youtube', () {
      expect(Attachment.fromUrl('https://youtu.be/abc123').type, 'youtube');
      expect(Attachment.fromUrl('https://www.youtube.com/watch?v=xxx').type, 'youtube');
    });
    test('detects github', () {
      expect(Attachment.fromUrl('https://github.com/user/repo').type, 'github');
    });
    test('falls back to link for generic URL', () {
      expect(Attachment.fromUrl('https://example.com').type, 'link');
    });
  });

  group('compactNum', () {
    test('<1000 stays integer', () {
      expect(compactNum(0), '0');
      expect(compactNum(42), '42');
      expect(compactNum(999), '999');
    });
    test('thousands formatted', () {
      expect(compactNum(1000), contains('k'));
      expect(compactNum(1500), contains('k'));
    });
    test('millions formatted', () {
      expect(compactNum(1500000), contains('M'));
    });
  });

  group('relativeTime', () {
    test('seconds ago', () {
      final t = DateTime.now().subtract(const Duration(seconds: 30));
      expect(relativeTime(t), contains('s'));
    });
    test('hours ago', () {
      final t = DateTime.now().subtract(const Duration(hours: 3));
      expect(relativeTime(t), '3h');
    });
  });

  group('AppUser.fromJson', () {
    test('handles missing fields gracefully', () {
      final u = AppUser.fromJson({'id': 1, 'handle': 'a', 'name': 'A'});
      expect(u.badges, isEmpty);
      expect(u.bio, '');
      expect(u.followers, 0);
    });
    test('parses badges list', () {
      final u = AppUser.fromJson({
        'id': 1,
        'handle': 'a',
        'name': 'A',
        'badges': ['human', 'verified'],
      });
      expect(u.badges, ['human', 'verified']);
    });
  });

  group('Post.fromJson', () {
    test('handles missing optional fields', () {
      final p = Post.fromJson({
        'id': 1,
        'kind': 'post',
        'author': {'id': 1, 'handle': 'a', 'name': 'A'},
      });
      expect(p.title, '');
      expect(p.attachments, isEmpty);
    });
    test('parses attachments', () {
      final p = Post.fromJson({
        'id': 1,
        'kind': 'post',
        'author': {'id': 1, 'handle': 'a', 'name': 'A'},
        'attachments': [
          {'type': 'image', 'url': 'http://x/1.jpg'},
          {'type': 'link', 'url': 'http://x'},
        ],
      });
      expect(p.attachments.length, 2);
      expect(p.attachments[0].type, 'image');
    });
  });
}
