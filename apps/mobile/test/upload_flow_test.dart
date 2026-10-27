import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbexpress/data/api/api_exception.dart';
import 'package:sbexpress/data/models/payment_review.dart';
import 'package:sbexpress/data/uploads/image_prepare.dart';
import 'package:sbexpress/data/uploads/photo_tray.dart';
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/data/uploads/upload_flow.dart';

PreparedImage sample() => PreparedImage(bytes: Uint8List.fromList([1, 2, 3]), filename: 'a.jpg', contentType: 'image/jpeg');

void main() {
  test('upload errors name storage, network, expiry and format', () {
    expect(describeUploadError(const ApiException(status: 503, message: 'storage not configured', path: '/x')), contains('স্টোরেজ'));
    expect(describeUploadError(const ApiException(status: 0, message: 'SocketException', path: '/x')), contains('নেটওয়ার্ক'));
    expect(describeUploadError(const ApiException(status: 400, message: 'Upload reservation expired', path: '/x')), contains('মেয়াদ'));
    expect(describeUploadError(const FormatException('ফরম্যাট মেলেনি। JPEG দিন।')), contains('ফরম্যাট'));
    expect(describeUploadError(const ApiException(status: 500, message: 'nope', path: '/x')), isNot('try again'));
  });

  test('a failed put retries the same bytes', () async {
    final seen = <Uint8List>[];
    var puts = 0;
    final reference = await transferPreparedUpload(
      file: sample(),
      reserve: (file) async => UploadReservation(reference: 'ref-$puts', uploadUrl: 'https://example.test/$puts', expiresAt: 'later'),
      put: (reservation, file, onProgress) async {
        puts += 1;
        seen.add(file.bytes);
        onProgress(0.4);
        if (puts == 1) throw ApiException(status: 0, message: 'network down', path: reservation.uploadUrl);
      },
      complete: (_) async {},
    );
    expect(reference, 'ref-1');
    expect(seen, hasLength(2));
    expect(identical(seen[0], seen[1]), isTrue);
  });

  test('a failed screenshot does not block payment', () async {
    final result = await optionalScreenshot(
      image: sample(),
      upload: (_) async => throw const ApiException(status: 0, message: 'connection reset', path: '/put'),
    );
    expect(result.attached, isFalse);
    expect(result.warning, contains('নেটওয়ার্ক'));
    expect(paymentSubmissionAllowed(result), isTrue);

    final missing = await optionalScreenshot(image: null, upload: (_) async => 'nope');
    expect(missing.reference, isNull);
    expect(paymentSubmissionAllowed(missing), isTrue);
  });

  test('approve stays available when the receipt has no screenshot', () {
    final item = PaymentReviewItem.shipment({
      'code': 'SH-9',
      'supplierCode': 'C-9',
      'supplierName': 'Nila',
      'method': 'bKash',
      'amount': 500,
      'sourceCurrency': 'BDT',
      'sourceAmount': 500,
      'txnRef': 'TX1',
      'date': '2026-10-18T00:00:00.000Z',
      'screenshot': null,
    });
    expect(item.hasScreenshot, isFalse);
    expect(canApprovePayment(item), isTrue);
  });

  // Was PhotoUploadController, which uploaded on select; the tray only
  // uploads on Upload, and Try again still sends the same prepared JPEG.
  test('photo retry uploads the prepared file without asking for another photo', () async {
    final uploaded = <int>[];
    final tray = PhotoTrayController(
      decodeHeic: (_) async => Uint8List(0),
      upload: (image, onProgress) async {
        uploaded.add(image.size);
        onProgress(1);
        if (uploaded.length == 1) throw const ApiException(status: 0, message: 'network', path: '/put');
      },
    );
    await tray.add([PickedPhoto(bytes: img.encodeJpg(img.Image(width: 2, height: 2)), name: 'a.jpg', mime: 'image/jpeg')]);
    expect(uploaded, isEmpty);
    await tray.uploadAll();
    final photo = tray.photos.single;
    expect(photo.error, contains('নেটওয়ার্ক'));
    expect(photo.prepared, isNotNull);
    final preparedSize = photo.prepared!.size;
    await tray.retry(photo);
    expect(tray.isEmpty, isTrue);
    expect(uploaded, [preparedSize, preparedSize]);
    tray.dispose();
  });
}
